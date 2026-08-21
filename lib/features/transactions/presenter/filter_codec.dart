import 'package:financeiro_ai/features/ledger/domain/entities/models.dart';
import 'package:financeiro_ai/features/transactions/domain/transaction_filter.dart';

/// The history filter, in the query string, so a slice of the ledger is a link.
///
/// Only what is set appears — a clear filter leaves the address clean.
abstract final class FilterCodec {
  static Map<String, String> encode(TransactionFilter filter) => {
    if (filter.query.trim().isNotEmpty) 'q': filter.query.trim(),
    if (filter.ignorePeriod) 'todoPeriodo': '1',
    if (filter.cardFinals.isNotEmpty) 'cartao': filter.cardFinals.join(','),
    if (filter.categories.isNotEmpty) 'categoria': filter.categories.join(','),
    if (filter.statuses.isNotEmpty)
      'estado': filter.statuses.map((s) => s.name).join(','),
    if (filter.minAmount != null) 'min': _amount(filter.minAmount!),
    if (filter.maxAmount != null) 'max': _amount(filter.maxAmount!),
    if (filter.onlyInstallments) 'parcelado': '1',
  };

  static TransactionFilter decode(Map<String, String> params) =>
      TransactionFilter(
        query: params['q'] ?? '',
        ignorePeriod: params['todoPeriodo'] == '1',
        cardFinals: _set(params['cartao']),
        categories: _set(params['categoria']),
        statuses: _set(params['estado'])
            .map(
              (name) => TransactionStatus.values
                  .where((value) => value.name == name)
                  .firstOrNull,
            )
            .whereType<TransactionStatus>()
            .toSet(),
        minAmount: double.tryParse(params['min'] ?? ''),
        maxAmount: double.tryParse(params['max'] ?? ''),
        onlyInstallments: params['parcelado'] == '1',
      );

  static Set<String> _set(String? value) => (value == null || value.isEmpty)
      ? const {}
      : value.split(',').where((part) => part.isNotEmpty).toSet();

  static String _amount(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';
}
