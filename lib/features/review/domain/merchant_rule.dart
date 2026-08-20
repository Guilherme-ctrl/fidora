import 'package:financeiro_ai/features/ledger/domain/finance_rules.dart';

/// A learned categorization rule: when a merchant name matches [pattern], the
/// transaction takes [categoryId]. Lower [priority] wins first.
class MerchantRule {
  const MerchantRule({
    required this.id,
    required this.pattern,
    required this.categoryId,
    required this.categoryName,
    this.subcategory,
    this.priority = 100,
    this.active = true,
  });

  final String id;
  final String pattern;
  final String categoryId;
  final String categoryName;
  final String? subcategory;
  final int priority;
  final bool active;

  /// Case- and accent-insensitive substring match.
  ///
  /// Mirrors `matchesPattern` in the capture Edge Function on purpose: the
  /// preview that tells the person how many transactions a pattern catches
  /// would be a lie if the two sides disagreed. Patterns under three characters
  /// never match, matching the editor's own rule.
  bool matches(String merchant) {
    final trimmed = pattern.trim();
    if (trimmed.length < 3) return false;
    return foldAccents(
      merchant,
    ).toUpperCase().contains(foldAccents(trimmed).toUpperCase());
  }
}

class MerchantRuleErrors {
  const MerchantRuleErrors({this.pattern, this.category});
  final String? pattern;
  final String? category;
  bool get isEmpty => pattern == null && category == null;
  String? get firstMessage => pattern ?? category;
}

class MerchantRuleDraft {
  const MerchantRuleDraft({
    required this.pattern,
    required this.categoryId,
    this.id,
    this.subcategory,
    this.priority = 100,
    this.active = true,
  });

  final String? id;
  final String pattern;
  final String categoryId;
  final String? subcategory;
  final int priority;
  final bool active;

  bool get isEdit => id != null;

  MerchantRuleErrors validate() => MerchantRuleErrors(
    pattern: switch (pattern.trim()) {
      '' => 'Informe o trecho do nome do estabelecimento',
      final value when value.length < 3 =>
        'Use ao menos 3 caracteres para evitar acertos indesejados',
      _ => null,
    },
    category: categoryId.trim().isEmpty ? 'Escolha uma categoria' : null,
  );
}
