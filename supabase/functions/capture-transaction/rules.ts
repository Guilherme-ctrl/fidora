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
