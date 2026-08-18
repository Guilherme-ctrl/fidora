import 'dart:math' as math;

import 'package:financeiro_ai/core/theme.dart';
import 'package:financeiro_ai/domain/analytics.dart';
import 'package:financeiro_ai/domain/models.dart';
import 'package:financeiro_ai/presentation/widgets/common.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    required this.snapshot,
    required this.period,
    required this.onPeriodChanged,
  });

  final FinanceSnapshot snapshot;
  final FinancePeriod period;
  final ValueChanged<FinancePeriod> onPeriodChanged;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 1250
        ? 4
        : width >= 680
        ? 2
        : 1;
    final analytics = analyzePeriod(snapshot, period);
    final cardExpenses = analytics.transactions
        .where((item) => item.affectsExpenses && isCardTransaction(item))
        .fold<double>(0, (sum, item) => sum + item.expenseImpact);
    final accountExpenses = analytics.transactions
        .where((item) => item.affectsExpenses && !isCardTransaction(item))
        .fold<double>(0, (sum, item) => sum + item.expenseImpact);
    final invoiceTotal = snapshot.invoices
        .where((item) => period.contains(item.referenceMonth))
        .fold<double>(0, (sum, item) => sum + item.total);

    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          width < 600 ? 18 : 32,
          24,
          width < 600 ? 18 : 32,
          36,
        ),
        children: [
          PageHeading(
            title: 'Seu dinheiro, com contexto.',
            subtitle: 'Indicadores de ${period.label}',
            action: width > 560
                ? Tooltip(
                    message: 'Registrar uma nova transação manualmente',
                    child: FilledButton.icon(
                      onPressed: () => _showCapture(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Nova transação'),
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 18),
          PeriodFilterBar(period: period, onChanged: onPeriodChanged),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: columns,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: width < 680 ? 2.15 : 1.7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              MetricCard(
                label: 'Saídas — faturas + conta',
                value: currency.format(analytics.expenses),
                icon: Icons.south_east_rounded,
                color: coral,
                detail:
                    '${analytics.transactions.where((item) => item.affectsExpenses && isCardTransaction(item)).length} no cartão',
                tooltip: 'Ver todas as saídas consideradas no período',
                onTap: () => _showTransactions(
                  context,
                  'Saídas no período',
                  analytics.transactions
                      .where((item) => item.affectsExpenses)
                      .toList(),
                ),
              ),
              MetricCard(
                label: 'Entradas no período',
                value: currency.format(analytics.income),
                icon: Icons.south_west_rounded,
                color: moss,
                detail:
                    '${analytics.transactions.where((item) => item.isIncome).length} entradas',
                tooltip: 'Ver créditos e entradas do período',
                onTap: () => _showTransactions(
                  context,
                  'Entradas no período',
                  analytics.transactions
                      .where((item) => item.isIncome)
                      .toList(),
                ),
              ),
              MetricCard(
                label: 'Saldo do período',
                value: currency.format(analytics.balance),
                icon: Icons.account_balance_wallet_rounded,
                color: analytics.balance >= 0 ? const Color(0xFF5D65A8) : coral,
                detail: '${analytics.savingsRate.toStringAsFixed(1)}% poupado',
                tooltip: 'Entender como entradas e saídas formam o saldo',
                onTap: () => showDetailSheet(
                  context,
                  title: 'Saldo de ${period.label}',
                  description:
                      'Saldo é a diferença entre entradas e saídas consideradas.',
                  child: Column(
                    children: [
                      DetailValue(
                        label: 'Entradas',
                        value: currency.format(analytics.income),
                      ),
                      DetailValue(
                        label: 'Saídas',
                        value: currency.format(analytics.expenses),
                      ),
                      DetailValue(
                        label: 'Cartão por fatura',
                        value: currency.format(cardExpenses),
                      ),
                      DetailValue(
                        label: 'Conta, Pix e débito',
                        value: currency.format(accountExpenses),
                      ),
                      DetailValue(
                        label: 'Saldo',
                        value: currency.format(analytics.balance),
                      ),
                    ],
                  ),
                ),
              ),
              MetricCard(
                label: 'Faturas no período',
                value: currency.format(invoiceTotal),
                icon: Icons.credit_card_rounded,
                color: gold,
                detail:
                    '${snapshot.invoices.where((item) => period.contains(item.referenceMonth)).length} faturas',
                tooltip: 'Ver faturas cuja competência está no período',
                onTap: () => _showInvoices(context),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final split = constraints.maxWidth >= 900;
              final chart = _TrendCard(analytics: analytics, period: period);
              final category = _CategoryCard(
                snapshot: snapshot,
                analytics: analytics,
                period: period,
              );
              return split
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: chart),
                        const SizedBox(width: 14),
                        Expanded(flex: 2, child: category),
                      ],
                    )
                  : Column(
                      children: [chart, const SizedBox(height: 14), category],
                    );
            },
          ),
          const SizedBox(height: 14),
          _BudgetComparison(
            snapshot: snapshot,
            analytics: analytics,
            period: period,
          ),
          const SizedBox(height: 14),
          _RecentTransactions(transactions: analytics.transactions),
        ],
      ),
    );
  }

  void _showCapture(BuildContext context) => showDetailSheet(
    context,
    title: 'Captura rápida',
    description:
        'O Atalho envia valor, estabelecimento e cartão. A categoria pode ser escolhida no Atalho ou revisada depois.',
    child: const Center(child: Icon(Icons.bolt_rounded, color: moss, size: 54)),
  );

  void _showTransactions(
    BuildContext context,
    String title,
    List<FinanceTransaction> transactions,
  ) => showDetailSheet(
    context,
    title: title,
    description:
        '${transactions.length} lançamentos encontrados em ${period.label}.',
    child: _TransactionDetails(transactions: transactions),
  );

  void _showInvoices(BuildContext context) {
    final invoices = snapshot.invoices
        .where((item) => period.contains(item.referenceMonth))
        .toList();
    showDetailSheet(
      context,
      title: 'Faturas de ${period.label}',
      description: 'Valores pessoais calculados para cada competência.',
      child: Column(
        children: invoices
            .map(
              (item) => DetailValue(
                label: monthYear.format(item.referenceMonth),
                value: currency.format(item.total),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.analytics, required this.period});
  final PeriodAnalytics analytics;
  final FinancePeriod period;

  @override
  Widget build(BuildContext context) {
    final totals = <DateTime, double>{};
    for (final item in analytics.transactions.where(
      (item) => item.affectsExpenses,
    )) {
      final day = DateTime(item.date.year, item.date.month, item.date.day);
      totals.update(
        day,
        (value) => value + item.expenseImpact,
        ifAbsent: () => item.expenseImpact,
      );
    }
    final days = totals.keys.toList()..sort();
    final spots = days.indexed
        .map((entry) => FlSpot(entry.$1.toDouble(), totals[entry.$2]!))
        .toList();

    return SectionCard(
      title: 'Ritmo de gastos',
      tooltip: 'Clique para ver os totais de cada dia',
      onTap: () => showDetailSheet(
        context,
        title: 'Ritmo diário de ${period.label}',
        description:
            'Datas reais das compras que compõem as faturas do período, somadas às movimentações de conta nas próprias datas.',
        child: Column(
          children: days
              .map(
                (day) => DetailValue(
                  label: DateFormat('dd/MM/yyyy').format(day),
                  value: currency.format(totals[day]),
                ),
              )
              .toList(),
        ),
      ),
      trailing: Text(
        '${days.length} dias com movimento',
        style: const TextStyle(color: moss, fontWeight: FontWeight.w700),
      ),
      child: SizedBox(
        height: 230,
        child: spots.isEmpty
            ? const Center(child: Text('Sem saídas neste período'))
            : LineChart(
                LineChartData(
                  minY: 0,
                  maxY: math.max(
                    1,
                    spots.map((item) => item.y).reduce(math.max) * 1.15,
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: ink.withValues(alpha: .06),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: const FlTitlesData(
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (items) => items
                          .map(
                            (item) => LineTooltipItem(
                              '${shortDate.format(days[item.x.toInt()])}\n${currency.format(item.y)}',
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: moss,
                      barWidth: 4,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: moss.withValues(alpha: .10),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.snapshot,
    required this.analytics,
    required this.period,
  });
  final FinanceSnapshot snapshot;
  final PeriodAnalytics analytics;
  final FinancePeriod period;

  @override
  Widget build(BuildContext context) {
    final entries = analytics.byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return SectionCard(
      title: 'Por categoria — faturas + conta',
      tooltip: 'Clique para abrir o detalhamento de todas as categorias',
      onTap: () => _showCategories(context, entries),
      child: Column(
        children: entries.take(5).map((entry) {
          final category = snapshot.categories
              .where((item) => item.name == entry.key)
              .firstOrNull;
          final ratio = analytics.expenses == 0
              ? 0.0
              : (entry.value / analytics.expenses).clamp(0.0, 1.0);
          return Tooltip(
            message: 'Ver lançamentos de ${entry.key}',
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => showDetailSheet(
                context,
                title: entry.key,
                description: 'Lançamentos desta categoria em ${period.label}.',
                child: _TransactionDetails(
                  transactions: analytics.transactions
                      .where((item) => item.category == entry.key)
                      .toList(),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 15),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 34,
                      decoration: BoxDecoration(
                        color: category?.color ?? moss,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.key,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 3),
                          LinearProgressIndicator(
                            value: ratio,
                            minHeight: 5,
                            borderRadius: BorderRadius.circular(8),
                            color: category?.color ?? moss,
                            backgroundColor: ink.withValues(alpha: .06),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      currency.format(entry.value),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showCategories(
    BuildContext context,
    List<MapEntry<String, double>> entries,
  ) => showDetailSheet(
    context,
    title: 'Categorias de ${period.label}',
    description: 'Distribuição de todas as saídas consideradas.',
    child: Column(
      children: entries
          .map(
            (entry) => DetailValue(
              label: entry.key,
              value: currency.format(entry.value),
            ),
          )
          .toList(),
    ),
  );
}

class _BudgetComparison extends StatelessWidget {
  const _BudgetComparison({
    required this.snapshot,
    required this.analytics,
    required this.period,
  });
  final FinanceSnapshot snapshot;
  final PeriodAnalytics analytics;
  final FinancePeriod period;

  @override
  Widget build(BuildContext context) {
    final items = snapshot.categories
        .where((item) => (item.monthlyBudget ?? 0) > 0)
        .toList();
    return SectionCard(
      title: 'Metas — faturas + conta versus realizado',
      tooltip:
          'Clique para comparar orçamento, realizado e saldo por categoria',
      onTap: () => _showDetails(context, items),
      trailing: Tooltip(
        message:
            'Metas mensais cadastradas na planilha e realizadas no período',
        child: Icon(
          Icons.info_outline_rounded,
          color: ink.withValues(alpha: .5),
        ),
      ),
      child: items.isEmpty
          ? const Text('Nenhuma meta mensal cadastrada.')
          : LayoutBuilder(
              builder: (context, constraints) => Wrap(
                spacing: 12,
                runSpacing: 12,
                children: items.map((category) {
                  final actual = analytics.byCategory[category.name] ?? 0;
                  final ratio = actual / category.monthlyBudget!;
                  final over = ratio > 1;
                  return Tooltip(
                    message: 'Abrir detalhes de ${category.name}',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _showCategory(context, category, actual),
                      child: Container(
                        width: constraints.maxWidth < 600
                            ? constraints.maxWidth
                            : 240,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: canvas,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              category.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${currency.format(actual)} / ${currency.format(category.monthlyBudget)}',
                              style: TextStyle(
                                color: over ? coral : moss,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 9),
                            LinearProgressIndicator(
                              value: ratio.clamp(0.0, 1.0),
                              minHeight: 8,
                              color: over ? coral : category.color,
                              backgroundColor: category.color.withValues(
                                alpha: .10,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
    );
  }

  void _showCategory(
    BuildContext context,
    FinanceCategory category,
    double actual,
  ) {
    final remaining = category.monthlyBudget! - actual;
    showDetailSheet(
      context,
      title: category.name,
      description:
          'Comparação da meta mensal com o realizado em ${period.label}.',
      child: Column(
        children: [
          DetailValue(
            label: 'Meta',
            value: currency.format(category.monthlyBudget),
          ),
          DetailValue(label: 'Realizado', value: currency.format(actual)),
          DetailValue(
            label: remaining >= 0 ? 'Disponível' : 'Excedente',
            value: currency.format(remaining.abs()),
          ),
          const Divider(height: 28),
          _TransactionDetails(
            transactions: analytics.transactions
                .where((item) => item.category == category.name)
                .toList(),
          ),
        ],
      ),
    );
  }

  void _showDetails(
    BuildContext context,
    List<FinanceCategory> items,
  ) => showDetailSheet(
    context,
    title: 'Metas versus realizado',
    description: 'Resumo das metas mensais cadastradas.',
    child: Column(
      children: items
          .map(
            (category) => DetailValue(
              label: category.name,
              value:
                  '${currency.format(analytics.byCategory[category.name] ?? 0)} / ${currency.format(category.monthlyBudget)}',
            ),
          )
          .toList(),
    ),
  );
}

class _RecentTransactions extends StatelessWidget {
  const _RecentTransactions({required this.transactions});
  final List<FinanceTransaction> transactions;

  @override
  Widget build(BuildContext context) => SectionCard(
    title: 'Últimas transações do período',
    tooltip: 'Clique para abrir todos os lançamentos deste período',
    onTap: () => showDetailSheet(
      context,
      title: 'Transações do período',
      description: '${transactions.length} lançamentos considerados.',
      child: _TransactionDetails(transactions: transactions),
    ),
    trailing: const Icon(Icons.open_in_new_rounded, size: 18, color: moss),
    child: _TransactionDetails(transactions: transactions.take(5).toList()),
  );
}

class _TransactionDetails extends StatelessWidget {
  const _TransactionDetails({required this.transactions});
  final List<FinanceTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return const Text('Nenhum lançamento encontrado.');
    }
    return Column(
      children: transactions
          .map(
            (item) => Tooltip(
              message: 'Ver os dados de ${item.merchant}',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: item.isIncome
                      ? mint
                      : coral.withValues(alpha: .12),
                  child: Icon(
                    item.isIncome
                        ? Icons.south_west_rounded
                        : Icons.receipt_rounded,
                    color: item.isIncome ? moss : coral,
                  ),
                ),
                title: Text(
                  item.merchant,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  isCardTransaction(item) && item.competence != null
                      ? 'Compra ${shortDate.format(item.date)} • fatura ${monthName.format(item.competence!)} • ${item.category}'
                      : '${shortDate.format(item.date)} • ${item.category}',
                ),
                trailing: Text(
                  currency.format(item.amount),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                onTap: () => showDetailSheet(
                  context,
                  title: item.merchant,
                  description: 'Detalhes do lançamento selecionado.',
                  child: Column(
                    children: [
                      DetailValue(
                        label: 'Data',
                        value: DateFormat('dd/MM/yyyy').format(item.date),
                      ),
                      if (isCardTransaction(item) && item.competence != null)
                        DetailValue(
                          label: 'Fatura',
                          value: monthYear.format(item.competence!),
                        ),
                      DetailValue(label: 'Categoria', value: item.category),
                      DetailValue(
                        label: 'Valor',
                        value: currency.format(item.amount),
                      ),
                      DetailValue(
                        label: 'Cartão',
                        value: 'final ${item.cardLastFour}',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
