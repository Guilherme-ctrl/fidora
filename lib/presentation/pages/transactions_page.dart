import 'package:financeiro_ai/core/theme.dart';
import 'package:financeiro_ai/domain/analytics.dart';
import 'package:financeiro_ai/domain/models.dart';
import 'package:financeiro_ai/presentation/widgets/common.dart';
import 'package:flutter/material.dart';

class TransactionsPage extends StatefulWidget {
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
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  String query = '';
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
    return ListView(
      padding: EdgeInsets.fromLTRB(
        width < 600 ? 18 : 32,
        24,
        width < 600 ? 18 : 32,
        36,
      ),
      children: [
        PageHeading(
          title: 'Histórico financeiro',
          subtitle: '${filtered.length} lançamentos em ${widget.period.label}.',
        ),
        const SizedBox(height: 16),
        PeriodFilterBar(
          period: widget.period,
          onChanged: widget.onPeriodChanged,
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: TextField(
                onChanged: (value) => setState(() => query = value),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Buscar estabelecimento ou categoria',
                ),
              ),
            ),
            if (width > 600) ...[
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
              Tooltip(
                message: 'Adicionar uma transação manual',
                child: FilledButton.icon(
                  onPressed: () => _showAdd(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar'),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: filtered
                  .map((item) => _TransactionRow(item: item))
                  .toList(),
            ),
          ),
        ),
      ],
    );
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

  void _showAdd(BuildContext context) => showDetailSheet(
    context,
    title: 'Nova transação',
    description:
        'Use o Atalho para captura automática ou registre manualmente.',
    child: const Center(
      child: Icon(Icons.add_circle_rounded, size: 52, color: moss),
    ),
  );
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.item});
  final FinanceTransaction item;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Abrir detalhes de ${item.merchant}',
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => showDetailSheet(
        context,
        title: item.merchant,
        description: 'Detalhes completos do lançamento selecionado.',
        child: Column(
          children: [
            DetailValue(
              label: 'Data',
              value:
                  '${item.date.day.toString().padLeft(2, '0')}/${item.date.month.toString().padLeft(2, '0')}/${item.date.year}',
            ),
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
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: item.status == TransactionStatus.pending
                    ? gold.withValues(alpha: .18)
                    : mint,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                item.status == TransactionStatus.pending
                    ? Icons.priority_high_rounded
                    : Icons.check_rounded,
                color: item.status == TransactionStatus.pending
                    ? const Color(0xFF8D6414)
                    : moss,
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
                    style: TextStyle(color: ink.withValues(alpha: .58)),
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
                  style: TextStyle(color: ink.withValues(alpha: .62)),
                ),
              ),
            if (MediaQuery.sizeOf(context).width > 480)
              SizedBox(
                width: 92,
                child: Text(
                  '•• ${item.cardLastFour}',
                  style: TextStyle(color: ink.withValues(alpha: .62)),
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
    ),
  );
}
