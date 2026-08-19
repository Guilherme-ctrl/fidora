import 'package:financeiro_ai/application/providers.dart';
import 'package:financeiro_ai/core/breakpoints.dart';
import 'package:financeiro_ai/core/theme.dart';
import 'package:financeiro_ai/core/tokens.dart';
import 'package:financeiro_ai/domain/analytics.dart';
import 'package:financeiro_ai/domain/models.dart';
import 'package:financeiro_ai/domain/transaction_draft.dart';
import 'package:financeiro_ai/domain/transaction_filter.dart';
import 'package:financeiro_ai/presentation/pages/merchant_rules_page.dart';
import 'package:financeiro_ai/presentation/widgets/filter_sheet.dart';
import 'package:financeiro_ai/presentation/widgets/common.dart';
import 'package:financeiro_ai/presentation/widgets/transaction_form_sheet.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TransactionsPage extends ConsumerStatefulWidget {
  const TransactionsPage({
    super.key,
    required this.snapshot,
    required this.period,
    required this.onPeriodChanged,
  });
  final FinanceSnapshot snapshot;
  final FinancePeriod period;
  final ValueChanged<FinancePeriod> onPeriodChanged;
  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage> {
  TransactionFilter _filter = const TransactionFilter();
  Timer? _debounce;

  /// Ids picked for a bulk change. Non-empty puts the list in selection mode.
  final Set<String> _selected = {};

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  /// Every keystroke used to refilter the ledger and rebuild every row. With
  /// the 847-row production ledger that was typing latency, so the filter now
  /// settles before it runs.
  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _filter = _filter.copyWith(query: value));
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
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
                            createTransaction(context, ref, widget.snapshot),
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
                      color: context.palette.brandSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${_selected.length} selecionado${_selected.length == 1 ? '' : 's'}',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: context.palette.onBrandSoft,
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
        else
          SliverPadding(
            padding: padding,
            sliver: SliverList.builder(
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final item = filtered[index];
                return Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(index == 0 ? 22 : 0),
                      bottom: Radius.circular(
                        index == filtered.length - 1 ? 22 : 0,
                      ),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: _TransactionRow(
                    item: item,
                    accounts: widget.snapshot.accounts,
                    selected: _selected.contains(item.id),
                    selecting: _selected.isNotEmpty,
                    onToggleSelect: () => setState(
                      () => _selected.contains(item.id)
                          ? _selected.remove(item.id)
                          : _selected.add(item.id),
                    ),
                    onEdit: () => createTransaction(
                      context,
                      ref,
                      widget.snapshot,
                      existing: item,
                    ),
                    onDelete: () => _confirmDelete(context, item),
                  ),
                );
              },
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 36)),
      ],
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    FinanceTransaction item,
  ) async {
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
              backgroundColor: context.palette.danger,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(financeRepositoryProvider).deleteTransaction(item.id);
      await refreshLedger(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lançamento excluído.'),
            backgroundColor: context.palette.brand,
          ),
        );
      }
    } on FinanceWriteException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message),
            backgroundColor: context.palette.danger,
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
    if (updated != null && mounted) setState(() => _filter = updated);
  }

  /// Applies one category to everything selected, then offers to remember it —
  /// the moment right after a correction is when the intent is clearest.
  Future<void> _recategorizeSelection() async {
    final category = await showModalBottomSheet<FinanceCategory>(
      context: context,
      showDragHandle: true,
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
      await ref
          .read(financeRepositoryProvider)
          .recategorizeTransactions(ids, category.id);
      await refreshLedger(ref);
      if (!mounted) return;
      setState(_selected.clear);
      final pattern = sample == null ? '' : suggestRulePattern(sample.merchant);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${ids.length} ${ids.length == 1 ? 'lançamento movido' : 'lançamentos movidos'} para ${category.name}.',
          ),
          backgroundColor: context.palette.brand,
          action: pattern.length < 3
              ? null
              : SnackBarAction(
                  label: 'Criar regra',
                  textColor: Colors.white,
                  onPressed: () => editRule(
                    context,
                    ref,
                    widget.snapshot,
                    suggestedPattern: pattern,
                  ),
                ),
        ),
      );
    } on FinanceWriteException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message),
            backgroundColor: context.palette.danger,
          ),
        );
      }
    }
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
  });
  final FinanceTransaction item;
  final List<Account> accounts;
  final bool selected;
  final bool selecting;
  final VoidCallback onToggleSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => InkWell(
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
                  ? context.palette.brand
                  : item.status == TransactionStatus.pending
                  ? context.palette.warning.withValues(alpha: .18)
                  : context.palette.brandSoft,
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
                  ? context.palette.onWarning
                  : context.palette.brand,
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
                    color: context.palette.brand,
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
        const SizedBox(height: 10),
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
                  foregroundColor: context.palette.danger,
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
