import 'package:financeiro_ai/core/theme/breakpoints.dart';
import 'package:financeiro_ai/core/theme/theme.dart';
import 'package:financeiro_ai/core/theme/typography.dart';
import 'package:financeiro_ai/core/theme/tokens.dart';
import 'package:financeiro_ai/features/overview/domain/analytics.dart';
import 'package:financeiro_ai/features/ledger/domain/entities/models.dart';
import 'package:financeiro_ai/features/transactions/domain/transaction_filter.dart';
import 'package:financeiro_ai/features/review/presenter/pages/merchant_rules_page.dart';
import 'package:financeiro_ai/features/transactions/presenter/widgets/filter_sheet.dart';
import 'package:financeiro_ai/core/design_system/common.dart';
import 'package:financeiro_ai/features/transactions/presenter/widgets/transaction_form_sheet.dart';
import 'dart:async';

import 'package:financeiro_ai/core/design_system/ledger.dart';
import 'package:financeiro_ai/core/errors/failure.dart';
import 'package:financeiro_ai/features/shared/widgets/failure_copy.dart';
import 'package:financeiro_ai/features/catalog/presenter/category_visuals.dart';
import 'package:financeiro_ai/features/ledger/presenter/cubits/finance_cubit.dart';
import 'package:financeiro_ai/features/ledger/domain/repositories/repositories.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({
    super.key,
    required this.snapshot,
    required this.period,
    required this.onPeriodChanged,
    required this.filter,
    required this.onFilterChanged,
  });
  final FinanceSnapshot snapshot;
  final FinancePeriod period;
  final ValueChanged<FinancePeriod> onPeriodChanged;

  /// The filter now lives in the address, not in this widget's state, so a
  /// slice of the ledger is a link and F5 keeps it.
  final TransactionFilter filter;
  final ValueChanged<TransactionFilter> onFilterChanged;
  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  Timer? _debounce;

  /// Seeded from the address, so a shared link shows the term it filtered by
  /// instead of an empty box over a filtered list.
  late final TextEditingController _query = TextEditingController(
    text: widget.filter.query,
  );

  TransactionFilter get _filter => widget.filter;

  /// Ids picked for a bulk change. Non-empty puts the list in selection mode.
  final Set<String> _selected = {};

  @override
  void didUpdateWidget(TransactionsPage old) {
    super.didUpdateWidget(old);
    // The address can change from outside the field — a cleared filter, a link
    // opened in place. Only write when they actually differ, or typing would
    // fight the controller.
    if (widget.filter.query != _query.text) {
      _query.text = widget.filter.query;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  /// Every keystroke used to refilter the ledger and rebuild every row. With
  /// the 847-row production ledger that was typing latency, so the filter now
  /// settles before it runs.
  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) widget.onFilterChanged(_filter.copyWith(query: value));
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    // Columns above `expanded`, stacked rows below. Same data, same selection,
    // same actions — only the presentation changes.
    final table = Breakpoint.of(context).hasTable;
    final filtered = filterTransactions(
      widget.snapshot,
      widget.period,
      _filter,
    );
    // Selecting rows and then narrowing the filter would otherwise leave
    // invisible rows staged for a change.
    _selected.retainWhere((id) => filtered.any((item) => item.id == id));
    final padding = EdgeInsets.symmetric(
      horizontal: Breakpoint.of(context).gutter,
    );

    // A Column of every matching row inside a ListView built all 847 rows on
    // each rebuild. A sliver list recycles them, so only what is on screen is
    // ever laid out.
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: padding.copyWith(top: 24),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PageHeading(
                  title: 'Histórico financeiro',
                  subtitle: _filter.ignorePeriod
                      ? '${filtered.length} lançamentos em todo o histórico.'
                      : '${filtered.length} lançamentos em ${widget.period.label}.',
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _query,
                        onChanged: _onQueryChanged,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Buscar estabelecimento ou categoria',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Badge(
                      isLabelVisible: _filter.activeCount > 0,
                      label: Text('${_filter.activeCount}'),
                      child: OutlinedButton.icon(
                        onPressed: _openFilters,
                        icon: const Icon(Icons.filter_list),
                        label: Text(width >= 700 ? 'Filtros' : ''),
                      ),
                    ),
                    // Below 900px the shell's action button owns this action,
                    // so a header button here would only duplicate it.
                    if (width >= 900) ...[
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () =>
                            createTransaction(context, widget.snapshot),
                        icon: const Icon(Icons.add),
                        label: const Text('Adicionar'),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                if (_selected.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                    decoration: BoxDecoration(
                      color: context.palette.accentSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${_selected.length} selecionado${_selected.length == 1 ? '' : 's'}',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: context.palette.accent,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(
                            () => _selected
                              ..clear()
                              ..addAll(filtered.map((item) => item.id)),
                          ),
                          child: const Text('Todos'),
                        ),
                        TextButton(
                          onPressed: () => setState(_selected.clear),
                          child: const Text('Cancelar'),
                        ),
                        FilledButton.icon(
                          onPressed: _recategorizeSelection,
                          icon: const Icon(
                            Icons.label_outline_rounded,
                            size: 18,
                          ),
                          label: const Text('Mover'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (filtered.isEmpty)
          SliverPadding(
            padding: padding,
            sliver: SliverToBoxAdapter(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 34),
                  child: Center(
                    child: Text(
                      _filter.query.trim().isEmpty
                          ? 'Nenhum lançamento com estes filtros.'
                          : 'Nada encontrado para “${_filter.query.trim()}”.',
                    ),
                  ),
                ),
              ),
            ),
          )
        else ...[
          if (table)
            SliverPadding(
              padding: padding.copyWith(bottom: 0),
              sliver: const SliverToBoxAdapter(child: _TableHeader()),
            ),
          SliverPadding(
            padding: padding.copyWith(top: table ? 0 : null),
            sliver: SliverList.builder(
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final item = filtered[index];
                // In table mode the row draws its own rules and ground, and a
                // rounded card behind it both looks wrong and asserts: a
                // borderRadius cannot sit on a border whose sides differ in
                // colour, which the selected row's left mark does.
                return Container(
                  decoration: table
                      ? null
                      : BoxDecoration(
                          color: Theme.of(context).cardTheme.color,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(index == 0 ? Radii.md : 0),
                            bottom: Radius.circular(
                              index == filtered.length - 1 ? Radii.md : 0,
                            ),
                          ),
                        ),
                  padding: EdgeInsets.symmetric(horizontal: table ? 0 : 8),
                  child: _TransactionRow(
                    item: item,
                    accounts: widget.snapshot.accounts,
                    table: table,
                    zebra: index.isOdd,
                    selected: _selected.contains(item.id),
                    selecting: _selected.isNotEmpty,
                    onToggleSelect: () => setState(
                      () => _selected.contains(item.id)
                          ? _selected.remove(item.id)
                          : _selected.add(item.id),
                    ),
                    onEdit: () => createTransaction(
                      context,
                      widget.snapshot,
                      existing: item,
                    ),
                    onDelete: () => _confirmDelete(context, item),
                  ),
                );
              },
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 36)),
      ],
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    FinanceTransaction item,
  ) async {
    final transactions = context.read<TransactionRepository>();
    final finance = context.read<FinanceCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir lançamento?'),
        content: Text(
          '${item.merchant} — ${currency.format(item.amount)}.\n'
          'Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.palette.negative,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await transactions.deleteTransaction(item.id);
      await finance.reloadLedger();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lançamento excluído.'),
            backgroundColor: context.palette.accent,
          ),
        );
      }
    } on Failure catch (failure) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(FailureCopy.of(failure).short),
            backgroundColor: context.palette.negative,
          ),
        );
      }
    }
  }

  Future<void> _openFilters() async {
    final updated = await showFilterSheet(
      context,
      snapshot: widget.snapshot,
      filter: _filter,
    );
    if (updated != null && mounted) widget.onFilterChanged(updated);
  }

  /// Applies one category to everything selected, then offers to remember it —
  /// the moment right after a correction is when the intent is clearest.
  Future<void> _recategorizeSelection() async {
    final transactions = context.read<TransactionRepository>();
    final finance = context.read<FinanceCubit>();
    final category = await showResponsiveSurface<FinanceCategory>(
      context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Text(
                'Mover ${_selected.length} ${_selected.length == 1 ? 'lançamento' : 'lançamentos'} para',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
            ),
            ...widget.snapshot.categories.map(
              (item) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: item.color.withValues(alpha: .18),
                  child: Icon(item.icon, color: item.color, size: 20),
                ),
                title: Text(item.name),
                onTap: () => Navigator.of(context).pop(item),
              ),
            ),
          ],
        ),
      ),
    );
    if (category == null || !mounted) return;

    final ids = _selected.toList();
    final sample = widget.snapshot.transactions
        .where((item) => item.id == ids.first)
        .firstOrNull;
    try {
      await transactions.recategorizeTransactions(ids, category.id);
      await finance.reloadLedger();
      if (!mounted) return;
      setState(_selected.clear);
      final pattern = sample == null ? '' : suggestRulePattern(sample.merchant);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${ids.length} ${ids.length == 1 ? 'lançamento movido' : 'lançamentos movidos'} para ${category.name}.',
          ),
          backgroundColor: context.palette.accent,
          action: pattern.length < 3
              ? null
              : SnackBarAction(
                  label: 'Criar regra',
                  textColor: Colors.white,
                  onPressed: () => editRule(
                    context,
                    widget.snapshot,
                    suggestedPattern: pattern,
                  ),
                ),
        ),
      );
    } on Failure catch (failure) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(FailureCopy.of(failure).short),
            backgroundColor: context.palette.negative,
          ),
        );
      }
    }
  }
}

/// The column widths, shared by the header and every row so they line up.
///
/// A ledger read on a wide screen needs columns: the eye loses the row between
/// the merchant and the number, which is exactly what a ruled column stops.
const _cols = (date: 1, merchant: 4, category: 2, card: 2, state: 2, amount: 2);

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    Widget cell(String label, int flex, {bool end = false}) => Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.xs),
        child: Align(
          alignment: end ? Alignment.centerRight : Alignment.centerLeft,
          child: SectionLabel(label),
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.only(bottom: Space.xs, left: 34),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: palette.ruleHeavy, width: Strokes.heavy),
        ),
      ),
      child: Row(
        children: [
          cell('data', _cols.date),
          cell('comerciante', _cols.merchant),
          cell('categoria', _cols.category),
          cell('cartão / conta', _cols.card),
          cell('estado', _cols.state),
          cell('valor', _cols.amount, end: true),
        ],
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({
    required this.item,
    required this.accounts,
    required this.selected,
    required this.selecting,
    required this.onToggleSelect,
    required this.onEdit,
    required this.onDelete,
    this.table = false,
    this.zebra = false,
  });
  final FinanceTransaction item;
  final List<Account> accounts;
  final bool selected;
  final bool selecting;
  final VoidCallback onToggleSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// Columns instead of a stacked card, above the `expanded` breakpoint.
  final bool table;
  final bool zebra;

  @override
  Widget build(BuildContext context) =>
      table ? _buildTable(context) : _buildCard(context);

  Widget _buildTable(BuildContext context) {
    final palette = context.palette;
    final type = context.type;

    Widget cell(Widget child, int flex, {bool end = false}) => Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.xs),
        child: Align(
          alignment: end ? Alignment.centerRight : Alignment.centerLeft,
          child: child,
        ),
      ),
    );

    return InkWell(
      onTap: selecting ? onToggleSelect : () => _openDetails(context),
      onLongPress: onToggleSelect,
      child: Container(
        decoration: BoxDecoration(
          color: selected
              ? palette.accentSoft
              : zebra
              ? palette.sunken
              : null,
          border: Border(
            top: BorderSide(color: palette.rule, width: Strokes.hairline),
            left: BorderSide(
              color: selected ? palette.accent : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: Space.xs),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Checkbox(
                value: selected,
                visualDensity: VisualDensity.compact,
                onChanged: (_) => onToggleSelect(),
              ),
            ),
            cell(
              Text(
                shortDate.format(item.date),
                style: type.meta.copyWith(color: palette.inkSubtle),
              ),
              _cols.date,
            ),
            cell(
              Row(
                children: [
                  CategoryMark(
                    text: CategoryMark.initials(item.merchant),
                    color: categoryColourFor(context, item.category),
                    size: 22,
                  ),
                  const SizedBox(width: Space.xs),
                  Expanded(
                    child: Text(
                      item.merchant,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: type.bodySm,
                    ),
                  ),
                ],
              ),
              _cols.merchant,
            ),
            cell(
              Text(
                item.category,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: type.bodySm.copyWith(color: palette.inkMuted),
              ),
              _cols.category,
            ),
            cell(
              Text(
                item.isCard ? '·${item.cardLastFour}' : _origin,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: type.meta.copyWith(color: palette.inkMuted),
              ),
              _cols.card,
            ),
            cell(switch (item.status) {
              TransactionStatus.pending => MonoTag(
                'revisar',
                color: palette.pending,
              ),
              TransactionStatus.ignored => MonoTag(
                'ignorado',
                color: palette.ignored,
              ),
              TransactionStatus.confirmed => const MonoTag('confirmado'),
            }, _cols.state),
            Expanded(
              flex: _cols.amount,
              child: Container(
                padding: const EdgeInsets.only(left: Space.sm),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: palette.rule,
                      width: Strokes.hairline,
                    ),
                  ),
                ),
                child: AmountText(
                  item.amount,
                  tone: item.status == TransactionStatus.ignored
                      ? MoneyTone.ignored
                      : item.isIncome
                      ? MoneyTone.income
                      : MoneyTone.expense,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(16),
    // Long press starts a selection; once one row is picked, tapping toggles
    // instead of opening, which is how a list like this usually behaves.
    onLongPress: onToggleSelect,
    onTap: selecting ? onToggleSelect : () => _openDetails(context),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: selected
                  ? context.palette.accent
                  : item.status == TransactionStatus.pending
                  ? context.palette.pending.withValues(alpha: .18)
                  : context.palette.accentSoft,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              selected
                  ? Icons.check_rounded
                  : item.status == TransactionStatus.pending
                  ? Icons.priority_high_rounded
                  : Icons.check_rounded,
              color: selected
                  ? Colors.white
                  // Was a hardcoded hex that survived the palette migration.
                  : item.status == TransactionStatus.pending
                  ? context.palette.pending
                  : context.palette.accent,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.merchant,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  isCardTransaction(item) && item.competence != null
                      ? 'Compra ${shortDate.format(item.date)} • fatura ${monthName.format(item.competence!)} • ${item.category}'
                      : '${shortDate.format(item.date)} • ${item.category}',
                  style: TextStyle(color: context.palette.inkMuted),
                ),
              ],
            ),
          ),
          if (MediaQuery.sizeOf(context).width > 650)
            Expanded(
              child: Text(
                item.isInstallment
                    ? '${item.installmentCurrent}/${item.installmentTotal} parcelas'
                    : 'À vista',
                style: TextStyle(color: context.palette.inkMuted),
              ),
            ),
          if (MediaQuery.sizeOf(context).width > 480)
            SizedBox(
              width: 92,
              child: Text(
                _origin,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: context.palette.inkMuted),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                currency.format(item.amount),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              // A shared charge shows both, so the row is never mistaken for
              // the full amount landing in your totals.
              if (item.isShared)
                Text(
                  'seu ${currency.format(item.personalShare)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: context.palette.accent,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, color: Colors.black26),
        ],
      ),
    ),
  );

  /// The card final, or the account name — anything that was not a card used
  /// to render as the literal "----".
  String get _origin {
    if (item.isCard) return '•• ${item.cardLastFour}';
    final account = accounts
        .where((entry) => entry.id == item.accountId)
        .firstOrNull;
    return account?.name ?? 'Conta';
  }

  void _openDetails(BuildContext context) => showDetailSheet(
    context,
    title: item.merchant,
    description: 'Detalhes completos do lançamento selecionado.',
    child: Column(
      children: [
        DetailValue(label: 'Data', value: longDate.format(item.date)),
        if (isCardTransaction(item) && item.competence != null)
          DetailValue(
            label: 'Fatura',
            value: monthYear.format(item.competence!),
          ),
        DetailValue(label: 'Categoria', value: item.category),
        DetailValue(label: 'Valor', value: currency.format(item.amount)),
        if (item.isShared) ...[
          DetailValue(
            label: 'Sua parte',
            value: currency.format(item.personalShare),
          ),
          DetailValue(
            label: 'De outra pessoa',
            value: currency.format(item.amount - item.personalShare),
          ),
        ],
        DetailValue(
          label: item.isCard ? 'Cartão' : 'Origem',
          value: item.isCard ? 'final ${item.cardLastFour}' : _origin,
        ),
        DetailValue(
          label: 'Modalidade',
          value: item.isInstallment
              ? '${item.installmentCurrent}/${item.installmentTotal} parcelas'
              : (item.rawModality ?? 'À vista'),
        ),
        // Where the number came from. Every one of these columns has existed
        // since the first migration and the query already asked for them; they
        // were never mapped into the model, so the app held the lineage and
        // could not show it. A total nobody can trace is a total nobody can
        // argue with.
        const SizedBox(height: Space.sm),
        _Lineage(item: item),
        const SizedBox(height: Space.sm),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  onEdit();
                },
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Editar'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.palette.negative,
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  onDelete();
                },
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Excluir'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

/// Where a row came from.
class _Lineage extends StatelessWidget {
  const _Lineage({required this.item});
  final FinanceTransaction item;

  static String _origin(String source) => switch (source) {
    'shortcut' => 'Atalho do iOS, no momento da compra',
    'manual' => 'Digitado no app',
    'invoice_import' => 'Importação de fatura',
    'statement_import' => 'Importação de extrato',
    _ => source,
  };

  static (String, Color) _confidence(BuildContext context, String value) =>
      switch (value) {
        'high' => ('alta', context.palette.income),
        'medium' => ('média', context.palette.pending),
        'low' => ('baixa', context.palette.negative),
        _ => (value, context.palette.inkSubtle),
      };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final confidence = item.confidence;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: Space.sm),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: palette.rule, width: Strokes.hairline),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('procedência'),
          const SizedBox(height: Space.xs),
          DetailValue(label: 'Entrou por', value: _origin(item.source)),
          if (item.sourceFile != null)
            DetailValue(label: 'Arquivo', value: item.sourceFile!),
          if (confidence != null)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.xs),
              child: Row(
                children: [
                  const Expanded(child: SectionLabel('Classificação')),
                  MonoTag(
                    'confiança ${_confidence(context, confidence).$1}',
                    color: _confidence(context, confidence).$2,
                  ),
                ],
              ),
            ),
          if (item.dedupKey != null)
            DetailValue(label: 'Chave de dedupe', value: item.dedupKey!),
          if (!item.hasLineage)
            Text(
              'Sem procedência registrada além da origem.',
              style: context.type.meta.copyWith(color: palette.inkSubtle),
            ),
        ],
      ),
    );
  }
}
