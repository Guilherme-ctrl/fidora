import 'package:financeiro_ai/application/providers.dart';
import 'package:financeiro_ai/core/theme.dart';
import 'package:financeiro_ai/domain/analytics.dart';
import 'package:financeiro_ai/domain/models.dart';
import 'package:financeiro_ai/domain/transaction_draft.dart';
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
  String query = '';
  Timer? _debounce;

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
      if (mounted) setState(() => query = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final filtered = widget.snapshot.transactions
        .where(
          (item) =>
              widget.period.contains(analyticsDate(item)) &&
              '${item.merchant} ${item.category}'.toLowerCase().contains(
                query.toLowerCase(),
              ),
        )
        .toList();
    final padding = EdgeInsets.symmetric(horizontal: width < 600 ? 18 : 32);

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
                  subtitle:
                      '${filtered.length} lançamentos em ${widget.period.label}.',
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
                    // Below 900px the shell's action button owns this action,
                    // so a header button here would only duplicate it.
                    if (width >= 900) ...[
                      const SizedBox(width: 12),
                      Tooltip(
                        message: 'Filtrar por categoria, cartão ou status',
                        child: OutlinedButton.icon(
                          onPressed: () => _showFilters(context),
                          icon: const Icon(Icons.filter_list),
                          label: const Text('Filtros'),
                        ),
                      ),
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
                      query.isEmpty
                          ? 'Nenhum lançamento neste período.'
                          : 'Nada encontrado para “$query”.',
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
      await refreshFinanceSnapshot(ref);
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

  void _showFilters(BuildContext context) => showDetailSheet(
    context,
    title: 'Filtros do histórico',
    description:
        'O período já está aplicado. A busca acima filtra por estabelecimento e categoria.',
    child: const Text(
      'Filtros avançados por cartão e status serão combinados com o período selecionado.',
    ),
  );
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });
  final FinanceTransaction item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(16),
    onTap: () => _openDetails(context),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: item.status == TransactionStatus.pending
                  ? context.palette.warning.withValues(alpha: .18)
                  : context.palette.brandSoft,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              item.status == TransactionStatus.pending
                  ? Icons.priority_high_rounded
                  : Icons.check_rounded,
              color: item.status == TransactionStatus.pending
                  ? const Color(0xFF8D6414)
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
                '•• ${item.cardLastFour}',
                style: TextStyle(color: context.palette.inkMuted),
              ),
            ),
          Text(
            currency.format(item.amount),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, color: Colors.black26),
        ],
      ),
    ),
  );

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
        DetailValue(label: 'Cartão', value: 'final ${item.cardLastFour}'),
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
