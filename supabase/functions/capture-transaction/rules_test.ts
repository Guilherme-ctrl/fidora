import { assertEquals } from "jsr:@std/assert@1";
import {
  decideCategory,
  matchesPattern,
  type MerchantRule,
  normalizeMerchant,
  selectRule, merchantIdentity } from "./rules.ts";

function rule(overrides: Partial<MerchantRule> = {}): MerchantRule {
  return {
    id: "r1",
    pattern: "IFOOD",
    category_id: "cat-food",
    subcategory: null,
    priority: 100,
    active: true,
    ...overrides,
  };
}

Deno.test("normalizeMerchant strips accents, symbols and case", () => {
  assertEquals(normalizeMerchant("  farmácia  são joão "), "FARMACIA SAO JOAO");
  assertEquals(normalizeMerchant("IFOOD *RESTAURANTE"), "IFOOD RESTAURANTE");
});

Deno.test("matchesPattern ignores case and accents", () => {
  assertEquals(matchesPattern("IFOOD *RESTAURANTE", "ifood"), true);
  assertEquals(matchesPattern("FARMACIA SAO JOAO", "farmácia"), true);
  assertEquals(matchesPattern("FARMÁCIA SÃO JOÃO", "farmacia"), true);
  assertEquals(matchesPattern("UBER EATS", "ifood"), false);
});

Deno.test("matchesPattern refuses patterns shorter than three characters", () => {
  // The rule editor blocks these too; a two-letter pattern would sweep up half
  // the ledger.
  assertEquals(matchesPattern("UBER", "UB"), false);
  assertEquals(matchesPattern("UBER", "UBE"), true);
});

Deno.test("selectRule takes the lowest priority number", () => {
  const chosen = selectRule(
    [
      rule({ id: "low", pattern: "IFOOD", priority: 50 }),
      rule({ id: "high", pattern: "IFOOD", priority: 10 }),
    ],
    "IFOOD *RESTAURANTE",
  );
  assertEquals(chosen?.id, "high");
});

Deno.test("selectRule breaks a priority tie with the longer pattern", () => {
  const chosen = selectRule(
    [
      rule({ id: "generic", pattern: "IFOOD", priority: 10 }),
      rule({ id: "specific", pattern: "IFOOD *MERCADO", priority: 10 }),
    ],
    "IFOOD *MERCADO CENTRAL",
  );
  assertEquals(chosen?.id, "specific");
});

Deno.test("selectRule ignores inactive rules", () => {
  assertEquals(
    selectRule([rule({ active: false })], "IFOOD *RESTAURANTE"),
    null,
  );
});

Deno.test("selectRule returns null when nothing matches", () => {
  assertEquals(selectRule([rule()], "POSTO SHELL"), null);
});

Deno.test("an explicit choice from the Shortcut beats a matching rule", () => {
  const decision = decideCategory({
    requestedCategoryId: "cat-chosen",
    requestedCategoryName: "Lazer",
    rules: [rule()],
    merchant: "IFOOD *RESTAURANTE",
    fallbackCategoryId: "cat-other",
  });
  assertEquals(decision.categoryId, "cat-chosen");
  assertEquals(decision.source, "shortcut");
  assertEquals(decision.needsReview, false);
});

Deno.test("a rule decides when nothing was chosen", () => {
  const decision = decideCategory({
    requestedCategoryId: null,
    requestedCategoryName: "",
    rules: [rule({ subcategory: "Delivery" })],
    merchant: "IFOOD *RESTAURANTE",
    fallbackCategoryId: "cat-other",
  });
  assertEquals(decision.categoryId, "cat-food");
  assertEquals(decision.subcategory, "Delivery");
  assertEquals(decision.source, "rule");
  assertEquals(decision.confidence, "medium");
  assertEquals(decision.needsReview, false);
  assertEquals(decision.note, 'Categoria definida pela regra "IFOOD".');
});

Deno.test("an unknown category name falls through to the rules", () => {
  const decision = decideCategory({
    requestedCategoryId: null,
    requestedCategoryName: "Categoria Que Nao Existe",
    rules: [rule()],
    merchant: "IFOOD *RESTAURANTE",
    fallbackCategoryId: "cat-other",
  });
  assertEquals(decision.source, "rule");
});

Deno.test("the capture is kept and queued when nothing settles it", () => {
  const decision = decideCategory({
    requestedCategoryId: null,
    requestedCategoryName: "",
    rules: [rule()],
    merchant: "POSTO SHELL",
    fallbackCategoryId: "cat-other",
  });
  assertEquals(decision.categoryId, "cat-other");
  assertEquals(decision.source, "fallback");
  assertEquals(decision.confidence, "low");
  assertEquals(decision.reviewed, false);
  assertEquals(decision.needsReview, true);
});

Deno.test("the fallback explains which name was rejected", () => {
  const decision = decideCategory({
    requestedCategoryId: null,
    requestedCategoryName: "Viagens Internacionais",
    rules: [],
    merchant: "POSTO SHELL",
    fallbackCategoryId: null,
  });
  assertEquals(
    decision.note,
    'A categoria "Viagens Internacionais" não existe e nenhuma regra casou com o estabelecimento.',
  );
  assertEquals(decision.categoryId, null);
  assertEquals(decision.needsReview, true);
});

Deno.test("merchantIdentity strips the instalment written inside the name", () => {
  // Ten instalments of one purchase were ten different merchants, so a rule
  // written on one never matched the next.
  assertEquals(merchantIdentity("LOJA X 03/10"), "LOJA X");
  assertEquals(merchantIdentity("LOJA X 03/10"), merchantIdentity("LOJA X 07/10"));
  assertEquals(merchantIdentity("MAGAZINE LUIZA D03/12"), "MAGAZINE LUIZA");
});

Deno.test("merchantIdentity strips the acquirer, keeps the shop", () => {
  assertEquals(merchantIdentity("PAYPAL*SPOTIFY"), "SPOTIFY");
  assertEquals(merchantIdentity("PAG    *PADARIA CENTRAL"), "PADARIA CENTRAL");
  assertEquals(merchantIdentity("PAYPAL*LOJA X 02/06"), "LOJA X");
});

Deno.test("merchantIdentity never returns nothing", () => {
  assertEquals(merchantIdentity("MERCADO EXTRA"), "MERCADO EXTRA");
  assertEquals(merchantIdentity("PAYPAL*"), "PAYPAL*");
});

Deno.test("the dedup normalisation is untouched by all of this", () => {
  // If this ever fails, a repeated capture stops matching the row it already
  // wrote and the person gets charged twice in their ledger.
  assertEquals(normalizeMerchant("PAYPAL*LOJA X 03/10"), "PAYPAL LOJA X 03 10");
});
