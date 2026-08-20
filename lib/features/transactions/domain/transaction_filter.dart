import 'package:financeiro_ai/features/overview/domain/analytics.dart';
import 'package:financeiro_ai/features/ledger/domain/finance_rules.dart';
import 'package:financeiro_ai/features/ledger/domain/entities/models.dart';

/// What the history screen is showing.
///
/// The search used to see only the selected period and match on merchant and
/// category alone, and the "Filtros" button opened a note saying filters were
/// coming. Everything here is combinable, and [ignorePeriod] is what makes the
/// search able to answer "when did I ever buy this?".
class TransactionFilter {
  const TransactionFilter({
    this.query = '',
    this.ignorePeriod = false,
    this.cardFinals = const {},
    this.categories = const {},
    this.statuses = const {},
    this.minAmount,
    this.maxAmount,
    this.onlyInstallments = false,
  });

  final String query;
  final bool ignorePeriod;

  /// Empty means every card, including account movements.
  final Set<String> cardFinals;
  final Set<String> categories;
  final Set<TransactionStatus> statuses;
  final double? minAmount;
  final double? maxAmount;
  final bool onlyInstallments;

  /// How many constraints beyond the text are active, for the badge on the
  /// filter button.
  int get activeCount =>
      (ignorePeriod ? 1 : 0) +
      (cardFinals.isEmpty ? 0 : 1) +
      (categories.isEmpty ? 0 : 1) +
      (statuses.isEmpty ? 0 : 1) +
      (minAmount == null && maxAmount == null ? 0 : 1) +
      (onlyInstallments ? 1 : 0);

  bool get isClear => activeCount == 0 && query.trim().isEmpty;

  TransactionFilter copyWith({
    String? query,
    bool? ignorePeriod,
    Set<String>? cardFinals,
    Set<String>? categories,
    Set<TransactionStatus>? statuses,
    double? minAmount,
    double? maxAmount,
    bool? onlyInstallments,
    bool clearMin = false,
    bool clearMax = false,
  }) => TransactionFilter(
    query: query ?? this.query,
    ignorePeriod: ignorePeriod ?? this.ignorePeriod,
    cardFinals: cardFinals ?? this.cardFinals,
    categories: categories ?? this.categories,
    statuses: statuses ?? this.statuses,
    minAmount: clearMin ? null : (minAmount ?? this.minAmount),
    maxAmount: clearMax ? null : (maxAmount ?? this.maxAmount),
    onlyInstallments: onlyInstallments ?? this.onlyInstallments,
  );
}

/// Applies the filter, newest first.
///
/// Text matching folds accents so `farmacia` finds `FARMÁCIA`, the same rule
/// the capture path and the rule editor use.
List<FinanceTransaction> filterTransactions(
  FinanceSnapshot snapshot,
  FinancePeriod period,
  TransactionFilter filter,
) {
  final query = foldAccents(filter.query.trim()).toUpperCase();
  final result = snapshot.transactions.where((item) {
    if (!filter.ignorePeriod && !period.contains(analyticsDate(item))) {
      return false;
    }
    if (query.isNotEmpty) {
      final haystack = foldAccents(
        '${item.merchant} ${item.category}',
      ).toUpperCase();
      if (!haystack.contains(query)) return false;
    }
    if (filter.cardFinals.isNotEmpty &&
        !filter.cardFinals.contains(item.cardLastFour)) {
      return false;
    }
    if (filter.categories.isNotEmpty &&
        !filter.categories.contains(item.category)) {
      return false;
    }
    if (filter.statuses.isNotEmpty && !filter.statuses.contains(item.status)) {
      return false;
    }
    if (filter.minAmount != null && item.amount < filter.minAmount!) {
      return false;
    }
    if (filter.maxAmount != null && item.amount > filter.maxAmount!) {
      return false;
    }
    if (filter.onlyInstallments && !item.isInstallment) return false;
    return true;
  }).toList()..sort((a, b) => b.date.compareTo(a.date));
  return result;
}

/// A pattern to offer after someone recategorizes something by hand.
///
/// The first word of the merchant is usually the brand and the rest is the
/// branch or the transaction reference, so `IFOOD *RESTAURANTE 123` suggests
/// `IFOOD`. Anything shorter than three characters would be refused by the rule
/// editor, so the whole name is offered instead.
String suggestRulePattern(String merchant) {
  final normalized = normalizeMerchant(merchant);
  if (normalized.isEmpty) return '';
  final first = normalized.split(' ').first;
  return first.length >= 3 ? first : normalized;
}
