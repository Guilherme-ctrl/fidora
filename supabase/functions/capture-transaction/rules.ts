/// Merchant normalization and rule matching.
///
/// Kept separate from the request handler so the decision that assigns a
/// category can be tested without a database or a running function.

export interface MerchantRule {
  id: string;
  pattern: string;
  category_id: string;
  subcategory: string | null;
  priority: number;
  active: boolean;
}

/// Strips diacritics so `FARMÁCIA` and `FARMACIA` are the same merchant.
export function foldAccents(value: string): string {
  return value.normalize("NFD").replace(/[̀-ͯ]/g, "");
}

/// Feeds `dedup_key`. **Do not change it.**
///
/// The key is stored per row. A different normalisation would stop a repeated
/// capture from matching the row it already wrote, and the Shortcut fires more
/// than once for one purchase often enough that this is the whole reason the
/// key exists. See `merchantIdentity` for the name the product displays.
export function normalizeMerchant(value: string): string {
  return foldAccents(value)
    .replace(/[^A-Za-z0-9 ]/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .toUpperCase();
}

/// Case- and accent-insensitive substring match.
///
/// This is deliberately the same rule the app's preview uses when it tells the
/// person how many existing transactions a pattern would catch. If the two
/// disagreed, the preview would be a promise the capture path does not keep.
export function matchesPattern(merchant: string, pattern: string): boolean {
  const trimmed = pattern.trim();
  if (trimmed.length < 3) return false;
  return foldAccents(merchant).toUpperCase().includes(
    foldAccents(trimmed).toUpperCase(),
  );
}

/// The rule that decides the category, or null when none applies.
///
/// Lowest priority number wins. Ties go to the longer pattern, because a longer
/// pattern is the more specific statement about the merchant; remaining ties
/// are broken alphabetically so the outcome never depends on row order.
export function selectRule(
  rules: readonly MerchantRule[],
  merchant: string,
): MerchantRule | null {
  const candidates = rules
    .filter((rule) => rule.active && matchesPattern(merchant, rule.pattern))
    .sort((a, b) =>
      a.priority - b.priority ||
      b.pattern.trim().length - a.pattern.trim().length ||
      a.pattern.localeCompare(b.pattern)
    );
  return candidates[0] ?? null;
}

export type CategorySource = "shortcut" | "rule" | "fallback";

export interface CategoryDecision {
  categoryId: string | null;
  subcategory: string | null;
  source: CategorySource;
  confidence: "high" | "medium" | "low";
  reviewed: boolean;
  needsReview: boolean;
  note: string | null;
}

/// Decides the category for a capture.
///
/// An explicit choice from the Shortcut always wins: the person picked it at
/// the moment of payment, and a learned rule should not overrule a deliberate
/// decision. Rules answer the case where nothing was chosen or the choice does
/// not exist. When neither settles it the capture is still kept — losing a
/// transaction is worse than filing it in the wrong place — and it goes to the
/// review queue instead.
export function decideCategory(input: {
  requestedCategoryId: string | null;
  requestedCategoryName: string;
  rules: readonly MerchantRule[];
  merchant: string;
  fallbackCategoryId: string | null;
}): CategoryDecision {
  if (input.requestedCategoryId) {
    return {
      categoryId: input.requestedCategoryId,
      subcategory: null,
      source: "shortcut",
      confidence: "high",
      reviewed: true,
      needsReview: false,
      note: null,
    };
  }

  const rule = selectRule(input.rules, input.merchant);
  if (rule) {
    return {
      categoryId: rule.category_id,
      subcategory: rule.subcategory,
      source: "rule",
      confidence: "medium",
      reviewed: true,
      needsReview: false,
      note: `Categoria definida pela regra "${rule.pattern.trim()}".`,
    };
  }

  return {
    categoryId: input.fallbackCategoryId,
    subcategory: null,
    source: "fallback",
    confidence: "low",
    reviewed: false,
    needsReview: true,
    note: input.requestedCategoryName
      ? `A categoria "${input.requestedCategoryName}" não existe e nenhuma regra casou com o estabelecimento.`
      : "Nenhuma categoria foi informada e nenhuma regra casou com o estabelecimento.",
  };
}


/// The name the same shop should always have.
///
/// Not [normalizeMerchant]: this one is for display and grouping, and changing
/// it is safe. Two things break a merchant's identity in a Brazilian statement
/// and both are mechanical — the instalment is written inside the name, so
/// `LOJA X 03/10` and `LOJA X 04/10` never meet; and the acquirer writes itself
/// in front, so `PAYPAL*SPOTIFY` files a Spotify charge under PayPal.
export function merchantIdentity(value: string): string {
  let name = value.trim();

  const aggregator = /^\s*([A-Za-z0-9.]{2,14})\s*\*\s*(.+)$/.exec(name);
  if (aggregator && aggregator[2].trim().length >= 3) {
    name = aggregator[2].trim();
  }

  name = name
    .replace(/\s*[A-Za-z]?\d{1,2}\s*\/\s*\d{1,2}\s*$/, "")
    .replace(/\s+/g, " ")
    .replace(/[\s\-–—.]+$/, "")
    .trim();

  return name.length === 0 ? value.trim() : name;
}
