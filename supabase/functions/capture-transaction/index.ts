import { createClient } from "npm:@supabase/supabase-js@2";
import {
  decideCategory,
  type MerchantRule,
  normalizeMerchant,
} from "./rules.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "content-type, x-shortcut-token",
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const token = request.headers.get("x-shortcut-token") ?? "";
  const body = await request.json();
  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const tokenHash = await sha256(token);
  const { data: shortcutToken, error: tokenLookupError } = await admin
    .from("shortcut_tokens")
    .select("id,user_id")
    .eq("token_hash", tokenHash)
    .is("revoked_at", null)
    .maybeSingle();

  if (tokenLookupError) {
    console.error("Shortcut token lookup failed", tokenLookupError.message);
    return json({ error: "token_lookup_failed" }, 500);
  }
  if (!shortcutToken) return json({ error: "invalid_token" }, 401);

  const amount = parseAmount(body.amount);
  const merchantOriginal = String(body.merchant ?? "").trim();
  const lastFour = String(body.card_last_four ?? "").replace(/\D/g, "").padStart(4, "0");
  const categoryName = String(body.category ?? "").trim();
  if (!Number.isFinite(amount) || amount <= 0 || !merchantOriginal || !lastFour) {
    return json({ error: "invalid_payload" }, 422);
  }

  const [{ data: card }, { data: chosenCategory }, { data: ruleRows }] =
    await Promise.all([
      admin.from("cards").select("*").eq("user_id", shortcutToken.user_id).eq("last_four", lastFour).eq("active", true).single(),
      categoryName
        ? admin.from("categories").select("id").eq("user_id", shortcutToken.user_id).eq("name", categoryName).eq("active", true).maybeSingle()
        : Promise.resolve({ data: null }),
      admin.from("merchant_rules")
        .select("id,pattern,category_id,subcategory,priority,active")
        .eq("user_id", shortcutToken.user_id)
        .eq("active", true)
        .order("priority"),
    ]);

  // A capture on an unknown card cannot be placed on an invoice, so this one
  // still fails. An unresolved category no longer does: the transaction is
  // recorded and queued for review instead of being lost at the till.
  if (!card) return json({ error: "card_not_found" }, 404);

  const { data: fallbackCategory } = await admin.from("categories")
    .select("id").eq("user_id", shortcutToken.user_id).eq("active", true)
    .eq("name", "Outros").maybeSingle();

  const decision = decideCategory({
    requestedCategoryId: chosenCategory?.id ?? null,
    requestedCategoryName: categoryName,
    rules: (ruleRows ?? []) as MerchantRule[],
    merchant: merchantOriginal,
    fallbackCategoryId: fallbackCategory?.id ?? null,
  });

  const purchasedAt = body.purchased_at ? new Date(body.purchased_at) : new Date();
  const competence = invoiceCompetence(purchasedAt, card.closing_day);
  const dueDate = new Date(competence.getFullYear(), competence.getMonth(), card.due_day);
  const month = isoDate(competence);
  const normalizedMerchant = normalizeMerchant(merchantOriginal);
  const dedupKey = await sha256(`${isoDate(purchasedAt)}|${lastFour}|${normalizedMerchant}|${amount.toFixed(2)}`);

  const { data: invoice, error: invoiceError } = await admin.from("invoices").upsert({
    user_id: shortcutToken.user_id,
    card_id: card.id,
    reference_month: month,
    due_date: isoDate(dueDate),
    status: "open",
  }, { onConflict: "card_id,reference_month", ignoreDuplicates: false }).select("id").single();
  if (invoiceError) return json({ error: invoiceError.message }, 500);

  const { data: transaction, error } = await admin.from("transactions").upsert({
    user_id: shortcutToken.user_id,
    dedup_key: dedupKey,
    purchased_at: purchasedAt.toISOString(),
    competence: month,
    card_id: card.id,
    invoice_id: invoice.id,
    holder_id: card.holder_id,
    merchant_original: merchantOriginal,
    merchant_normalized: normalizedMerchant,
    amount,
    category_id: decision.categoryId,
    subcategory: decision.subcategory,
    movement_type: "purchase",
    modality: "cash",
    status: "confirmed",
    source: "apple_pay",
    confidence: decision.confidence,
    reviewed: decision.reviewed,
    notes: decision.note,
  }, { onConflict: "user_id,dedup_key", ignoreDuplicates: true }).select("id").maybeSingle();

  await admin.from("shortcut_tokens").update({ last_used_at: new Date().toISOString() }).eq("id", shortcutToken.id);
  if (error) return json({ error: error.message }, 500);

  // Only a row that was actually created needs a review; a duplicate capture
  // already has whatever review its original got.
  if (decision.needsReview && transaction) {
    await admin.from("review_queue").upsert({
      user_id: shortcutToken.user_id,
      transaction_id: transaction.id,
      reason: decision.note ?? "Classificação pendente",
      status: "pending",
      item_type: "transaction",
      description: merchantOriginal,
      suggested_action: "Confirmar categoria",
      raw_payload: body,
    }, { onConflict: "transaction_id,reason", ignoreDuplicates: true });
  }

  return json({
    ok: true,
    duplicate: transaction === null,
    transaction_id: transaction?.id ?? null,
    category_source: decision.source,
    needs_review: decision.needsReview,
  });
});

function parseAmount(value: unknown): number {
  if (typeof value === "number") return value;
  let text = String(value ?? "").replace(/[^\d,.-]/g, "");
  if (text.includes(",")) text = text.replaceAll(".", "").replace(",", ".");
  return Number(text);
}

function invoiceCompetence(date: Date, closingDay: number): Date {
  return new Date(date.getFullYear(), date.getMonth() + (date.getDate() > closingDay ? 1 : 0), 1);
}

function isoDate(date: Date): string {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

async function sha256(value: string): Promise<string> {
  const bytes = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return Array.from(new Uint8Array(bytes)).map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } });
}
