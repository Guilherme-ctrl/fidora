import 'package:financeiro_ai/core/theme.dart';
import 'package:financeiro_ai/domain/amount_input.dart';
import 'package:financeiro_ai/domain/models.dart';
import 'package:financeiro_ai/domain/transaction_filter.dart';
import 'package:flutter/material.dart';

/// Returns the edited filter, or null when the sheet was dismissed.
Future<TransactionFilter?> showFilterSheet(
  BuildContext context, {
  required FinanceSnapshot snapshot,
  required TransactionFilter filter,
}) => showModalBottomSheet<TransactionFilter>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) => _FilterSheet(snapshot: snapshot, filter: filter),
);

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.snapshot, required this.filter});
  final FinanceSnapshot snapshot;
  final TransactionFilter filter;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late TransactionFilter _draft;
  late final TextEditingController _min;
  late final TextEditingController _max;

  String _money(double? value) =>
      value == null ? '' : value.toStringAsFixed(2).replaceAll('.', ',');

  @override
  void initState() {
    super.initState();
    _draft = widget.filter;
    _min = TextEditingController(text: _money(widget.filter.minAmount));
    _max = TextEditingController(text: _money(widget.filter.maxAmount));
  }

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  Set<T> _toggled<T>(Set<T> current, T value) {
    final next = {...current};
    next.contains(value) ? next.remove(value) : next.add(value);
    return next;
  }

  @override
  Widget build(BuildContext context) {
    // Every final that appears in the data, not only the registered cards: a
    // migrated ledger can hold charges from a card that was never cadastrado,
    // and those rows would otherwise be unfilterable.
    final finals = <String>{
      ...widget.snapshot.cards.map((card) => card.lastFour),
      ...widget.snapshot.transactions.map((item) => item.cardLastFour),
    }.toList()..sort();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .88,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Filtros',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    if (!_draft.isClear)
                      TextButton(
                        onPressed: () => setState(
                          () => _draft = TransactionFilter(query: _draft.query),
                        ),
                        child: const Text('Limpar'),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _draft.ignorePeriod,
                  onChanged: (value) => setState(
                    () => _draft = _draft.copyWith(ignorePeriod: value),
                  ),
                  title: const Text(
                    'Buscar em todo o histórico',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Ignora o período selecionado nas outras telas.',
                  ),
                ),
                const Divider(height: 24),
                _Label('Cartão'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: finals
                      .map(
                        (value) => FilterChip(
                          label: Text(
                            value == '----'
                                ? 'Conta, Pix, débito'
                                : '•• $value',
                          ),
                          selected: _draft.cardFinals.contains(value),
                          onSelected: (_) => setState(
                            () => _draft = _draft.copyWith(
                              cardFinals: _toggled(_draft.cardFinals, value),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 18),
                _Label('Categoria'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.snapshot.categories
                      .map(
                        (category) => FilterChip(
                          avatar: CircleAvatar(
                            backgroundColor: category.color,
                            radius: 7,
                          ),
                          label: Text(category.name),
                          selected: _draft.categories.contains(category.name),
                          onSelected: (_) => setState(
                            () => _draft = _draft.copyWith(
                              categories: _toggled(
                                _draft.categories,
                                category.name,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 18),
                _Label('Situação'),
                Wrap(
                  spacing: 8,
                  children: TransactionStatus.values
                      .map(
                        (status) => FilterChip(
                          label: Text(switch (status) {
                            TransactionStatus.confirmed => 'Confirmado',
                            TransactionStatus.pending => 'Pendente',
                            TransactionStatus.ignored => 'Ignorado',
                          }),
                          selected: _draft.statuses.contains(status),
                          onSelected: (_) => setState(
                            () => _draft = _draft.copyWith(
                              statuses: _toggled(_draft.statuses, status),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 18),
                _Label('Valor'),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _min,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'De',
                          prefixText: 'R\$ ',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _max,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Até',
                          prefixText: 'R\$ ',
                        ),
                      ),
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _draft.onlyInstallments,
                  onChanged: (value) => setState(
                    () => _draft = _draft.copyWith(onlyInstallments: value),
                  ),
                  title: const Text(
                    'Somente parcelados',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(
                    _draft.copyWith(
                      minAmount: parseAmountInput(_min.text),
                      maxAmount: parseAmountInput(_max.text),
                      clearMin: parseAmountInput(_min.text) == null,
                      clearMax: parseAmountInput(_max.text) == null,
                    ),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 13),
                    child: Text('Aplicar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 13,
        color: context.palette.inkMuted,
      ),
    ),
  );
}
