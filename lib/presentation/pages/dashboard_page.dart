import 'dart:math' as math;

import 'package:financeiro_ai/core/breakpoints.dart';
import 'package:financeiro_ai/core/theme.dart';
import 'package:financeiro_ai/core/tokens.dart';
import 'package:financeiro_ai/domain/analytics.dart';
import 'package:financeiro_ai/domain/comparison.dart';
import 'package:financeiro_ai/domain/insights.dart';
import 'package:financeiro_ai/domain/models.dart';
import 'package:financeiro_ai/presentation/widgets/common.dart';
import 'package:financeiro_ai/presentation/widgets/ledger.dart';
import 'package:financeiro_ai/presentation/widgets/insights_card.dart';
import 'package:financeiro_ai/presentation/widgets/transaction_form_sheet.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class DashboardPage extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 1250
        ? 4
        : width >= 680
        ? 2
        : 1;
    final analytics = analyzePeriod(snapshot, period);
    final comparison = comparePeriods(snapshot, period);
    final average = trailingMonthlyAverage(snapshot, period);
    final cardExpenses = analytics.transactions
        .where((item) => item.affectsExpenses && isCardTransaction(item))
        .fold<double>(0, (sum, item) => sum + item.expenseImpact);
    final accountExpenses = analytics.transactions
        .where((item) => item.affectsExpenses && !isCardTransaction(item))
        .fold<double>(0, (sum, item) => sum + item.expenseImpact);
    final invoiceTotal = snapshot.invoices
        .where((item) => period.contains(item.referenceMonth))
        .fold<double>(0, (sum, item) => sum + item.total);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        Breakpoint.of(context).gutter,
        Space.xl,
        Breakpoint.of(context).gutter,
        Space.xxxl,
      ),
      children: [
        PageHeading(
          title: 'Seu dinheiro, com contexto.',
          subtitle: 'Indicadores de ${period.label}',
          // Below 900px the shell's floating action button owns this action.
          action: width >= 900
              ? FilledButton.icon(
                  onPressed: () => createTransaction(context, ref, snapshot),
                  icon: const Icon(Icons.add),
                  label: const Text('Nova transação'),
                )
              : null,
        ),
        const SizedBox(height: 18),
        _BudgetWarning(alerts: budgetAlerts(snapshot, period)),
        // Rows of intrinsic height rather than a grid of fixed aspect ratio.
        // The ratio approach sized every cell from a guessed height, and a
        // trend line — which only renders once there is a previous month —
        // pushed the content past it. That overflow shipped invisible while
        // the demo held a single month. Rows that measure their own content
        // cannot overflow at any text scale, and stretching the cards makes
        // the values in a row share a baseline.
        Builder(
          builder: (context) {
            final metrics = <Widget>[
              LedgerTile(
                label: 'Saídas — faturas + conta',
                value: currency.format(analytics.expenses),
                detail:
                    '${analytics.transactions.where((item) => item.affectsExpenses && isCardTransaction(item)).length} no cartão',
                trendLabel: _expenseTrend(comparison),
                // Spending less than the baseline is the good direction.
                trendGood: comparison.hasBaseline
                    ? !comparison.spentMore
                    : null,
                tooltip: 'Ver todas as saídas consideradas no período',
                onTap: () => _showTransactions(
                  context,
                  'Saídas no período',
                  analytics.transactions
                      .where((item) => item.affectsExpenses)
                      .toList(),
                ),
              ),
              LedgerTile(
                label: 'Entradas no período',
                value: currency.format(analytics.income),
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
              LedgerTile(
                label: 'Saldo do período',
                value: currency.format(analytics.balance),
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
              LedgerTile(
                label: 'Faturas no período',
                value: currency.format(invoiceTotal),
                detail:
                    '${snapshot.invoices.where((item) => period.contains(item.referenceMonth)).length} faturas',
                tooltip: 'Ver faturas cuja competência está no período',
                onTap: () => _showInvoices(context),
              ),
            ];

            return Column(
              children: [
                for (var row = 0; row < metrics.length; row += columns) ...[
                  if (row > 0) const SizedBox(height: 14),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var slot = 0; slot < columns; slot++) ...[
                          if (slot > 0) const SizedBox(width: 14),
                          Expanded(
                            child: row + slot < metrics.length
                                ? metrics[row + slot]
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        // After the numbers, before the breakdowns: it reads as the answer to
        // the numbers above, and the charts below are where someone goes to
        // check it. Removes itself when there is nothing worth saying.
        InsightsCard(snapshot: snapshot, period: period),
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
        _MonthOverMonth(comparison: comparison, average: average),
        const SizedBox(height: 14),
        _BudgetComparison(
          snapshot: snapshot,
          analytics: analytics,
          period: period,
        ),
        const SizedBox(height: 14),
        _RecentTransactions(transactions: analytics.transactions),
      ],
    );
  }

  /// Null when the previous period spent nothing — there is no percentage
  /// change from zero, and inventing one would be worse than saying nothing.
  static String? _expenseTrend(PeriodComparison comparison) {
    if (!comparison.hasBaseline) return null;
    final ratio = comparison.expenseRatio!;
    final direction = ratio >= 0 ? 'acima' : 'abaixo';
    final label = monthName.format(comparison.previousPeriod.start);
    return '${(ratio.abs() * 100).toStringAsFixed(0)}% $direction de $label';
  }

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
    // The x axis is the calendar, not the list of days that happened to have
    // movement. Indexing by the latter collapsed the gaps, so a purchase on the
    // 3rd and another on the 28th were drawn side by side and the "pace" the
    // chart is named after was exactly what it hid.
    final firstDay = DateTime(
      period.start.year,
      period.start.month,
      period.start.day,
    );
    final span = period.endExclusive.difference(firstDay).inDays;
    final days = List.generate(
      span,
      (index) => DateTime(firstDay.year, firstDay.month, firstDay.day + index),
    );
    final spots = days.indexed
        .map((entry) => FlSpot(entry.$1.toDouble(), totals[entry.$2] ?? 0))
        .toList();
    final daysWithMovement = totals.keys.length;
    final peak = totals.values.isEmpty ? 0.0 : totals.values.reduce(math.max);

    return RuledSection(
      title: 'Ritmo de gastos',
      tooltip: 'Clique para ver os totais de cada dia',
      onTap: () => showDetailSheet(
        context,
        title: 'Ritmo diário de ${period.label}',
        description:
            'Datas reais das compras que compõem as faturas do período, somadas às movimentações de conta nas próprias datas.',
        child: Column(
          children: (totals.keys.toList()..sort())
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
        '$daysWithMovement de ${days.length} dias',
        style: TextStyle(
          color: context.palette.accent,
          fontWeight: FontWeight.w700,
        ),
      ),
      child: SizedBox(
        height: 230 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.4),
        child: spots.isEmpty
            ? const Center(child: Text('Sem saídas neste período'))
            : LineChart(
                LineChartData(
                  minY: 0,
                  maxY: math.max(1, peak * 1.15),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) =>
                        FlLine(color: context.palette.rule, strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 46,
                        getTitlesWidget: (value, meta) =>
                            value >= meta.max || value <= 0
                            ? const SizedBox()
                            : Text(
                                compactCurrency.format(value),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: context.palette.inkSubtle,
                                ),
                              ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        interval: math.max(
                          1,
                          (days.length / 5).floorToDouble(),
                        ),
                        getTitlesWidget: (value, meta) {
                          final index = value.round();
                          if (index < 0 || index >= days.length) {
                            return const SizedBox();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              DateFormat('d/M').format(days[index]),
                              style: TextStyle(
                                fontSize: 10,
                                color: context.palette.inkSubtle,
                              ),
                            ),
                          );
                        },
                      ),
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
                      color: context.palette.accent,
                      barWidth: 4,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: context.palette.accent.withValues(alpha: .10),
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
    return RuledSection(
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
          return Semantics(
            label: 'Ver lançamentos de ${entry.key}',
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
                        color: category?.color ?? context.palette.accent,
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
                          RuleBar(
                            value: ratio,
                            color: category?.color ?? context.palette.accent,
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
    return RuledSection(
      title: 'Metas — faturas + conta versus realizado',
      tooltip:
          'Clique para comparar orçamento, realizado e saldo por categoria',
      onTap: () => _showDetails(context, items),
      trailing: Semantics(
        label: 'Metas mensais cadastradas na planilha e realizadas no período',
        child: Icon(
          Icons.info_outline_rounded,
          color: context.palette.inkSubtle,
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
                  return Semantics(
                    label: 'Abrir detalhes de ${category.name}',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _showCategory(context, category, actual),
                      child: Container(
                        width: constraints.maxWidth < 600
                            ? constraints.maxWidth
                            : 240,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: context.palette.canvas,
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
                                color: over
                                    ? context.palette.negative
                                    : context.palette.accent,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 9),
                            RuleBar(
                              value: ratio.clamp(0.0, 1.0),
                              over: over,
                              color: category.color,
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
  Widget build(BuildContext context) => RuledSection(
    title: 'Últimas transações do período',
    tooltip: 'Clique para abrir todos os lançamentos deste período',
    onTap: () => showDetailSheet(
      context,
      title: 'Transações do período',
      description: '${transactions.length} lançamentos considerados.',
      child: _TransactionDetails(transactions: transactions),
    ),
    trailing: Icon(
      Icons.open_in_new_rounded,
      size: 18,
      color: context.palette.accent,
    ),
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
    // The ledger line, not a ListTile: the amount sits in its own column behind
    // a vertical rule, and the row is zebra-striped. An ordinary spend renders
    // in ink — every row here used to be red, which said "problem" about the
    // most ordinary thing the product records.
    return Column(
      children: [
        for (final (index, item) in transactions.indexed)
          Semantics(
            label: 'Ver os dados de ${item.merchant}',
            child: LedgerRow(
              title: item.merchant,
              meta: isCardTransaction(item) && item.competence != null
                  ? '${shortDate.format(item.date)} · fatura ${monthName.format(item.competence!)} · ${item.category}'
                  : '${shortDate.format(item.date)} · ${item.category}',
              amount: item.amount,
              tone: item.isIncome ? MoneyTone.income : MoneyTone.expense,
              markColor: categoryColourFor(context, item.category),
              zebra: index.isOdd,
              first: index == 0,
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
      ],
    );
  }
}

/// Answers “estou gastando mais que o normal?”, which nothing on the dashboard
/// could answer before: every figure was an isolated total.
class _MonthOverMonth extends StatelessWidget {
  const _MonthOverMonth({required this.comparison, required this.average});
  final PeriodComparison comparison;
  final double? average;

  @override
  Widget build(BuildContext context) {
    final movers = comparison.categories
        .where((item) => item.delta.abs() >= 0.01)
        .take(5)
        .toList();
    final previousLabel = monthYear.format(comparison.previousPeriod.start);

    return RuledSection(
      title: 'Comparado com $previousLabel',
      tooltip: 'Ver o detalhe da variação por categoria',
      onTap: () => _showAll(context),
      trailing: average == null
          ? null
          : Text(
              'média ${currency.format(average)}',
              style: TextStyle(
                color: context.palette.inkMuted,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!comparison.hasBaseline)
            Text(
              'Não há gastos em $previousLabel para comparar.',
              style: TextStyle(color: context.palette.inkMuted),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    comparison.spentMore
                        ? 'Você gastou ${currency.format(comparison.expenseDelta.abs())} a mais'
                        : 'Você gastou ${currency.format(comparison.expenseDelta.abs())} a menos',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: comparison.spentMore
                          ? context.palette.negative
                          : context.palette.accent,
                    ),
                  ),
                ),
                Text(
                  '${currency.format(comparison.previous.expenses)} → ${currency.format(comparison.current.expenses)}',
                  style: TextStyle(
                    color: context.palette.inkMuted,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          if (movers.isEmpty)
            Text(
              'Nenhuma categoria mudou no período.',
              style: TextStyle(color: context.palette.inkMuted),
            )
          else
            ...movers.map((item) => _DeltaRow(item: item)),
        ],
      ),
    );
  }

  void _showAll(BuildContext context) => showDetailSheet(
    context,
    title: 'Variação por categoria',
    description:
        'Comparação entre ${monthYear.format(comparison.period.start)} e ${monthYear.format(comparison.previousPeriod.start)}.',
    child: Column(
      children: comparison.categories
          .map(
            (item) => DetailValue(
              label: item.name,
              value:
                  '${currency.format(item.previous)} → ${currency.format(item.current)}',
            ),
          )
          .toList(),
    ),
  );
}

class _DeltaRow extends StatelessWidget {
  const _DeltaRow({required this.item});
  final CategoryDelta item;

  @override
  Widget build(BuildContext context) {
    final up = item.delta > 0;
    final color = up ? context.palette.negative : context.palette.income;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            switch (item) {
              final value when value.isNew => 'novo',
              final value when value.isGone => 'zerou',
              _ =>
                '${up ? '+' : '−'}${(item.ratio!.abs() * 100).toStringAsFixed(0)}%',
            },
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 96,
            child: Text(
              '${up ? '+' : '−'}${currency.format(item.delta.abs())}',
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

/// Says a budget is running out while there is still month left to act on it.
/// Sits above the figures on purpose: by the time you scroll to the budget
/// section, you have already read the totals and moved on.
class _BudgetWarning extends StatelessWidget {
  const _BudgetWarning({required this.alerts});
  final List<BudgetAlert> alerts;

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) return const SizedBox.shrink();
    final over = alerts.where((item) => item.level == BudgetLevel.over).length;
    final worst = alerts.first;
    final danger = over > 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Semantics(
        button: true,
        label: 'Ver as categorias que estouraram ou estão perto do limite',
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => showDetailSheet(
            context,
            title: 'Orçamentos no limite',
            description:
                'Categorias com 80% ou mais do orçamento mensal consumido.',
            child: Column(
              children: alerts
                  .map(
                    (item) => DetailValue(
                      label: item.category.name,
                      value:
                          '${currency.format(item.spent)} de ${currency.format(item.budget)}'
                          ' • ${(item.ratio * 100).toStringAsFixed(0)}%',
                    ),
                  )
                  .toList(),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: danger
                  ? context.palette.negative.withValues(alpha: .12)
                  : context.palette.pending.withValues(alpha: .16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  danger
                      ? Icons.error_outline_rounded
                      : Icons.warning_amber_rounded,
                  color: danger
                      ? context.palette.negative
                      : context.palette.pending,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    switch ((over, alerts.length)) {
                      (0, 1) =>
                        '${worst.category.name} usou ${(worst.ratio * 100).toStringAsFixed(0)}% do orçamento.',
                      (0, final total) =>
                        '$total categorias passaram de 80% do orçamento.',
                      (1, _) =>
                        '${worst.category.name} estourou o orçamento em ${currency.format(worst.remaining.abs())}.',
                      (final count, _) =>
                        '$count categorias estouraram o orçamento.',
                    },
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: danger
                          ? context.palette.negative
                          : context.palette.pending,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: danger
                      ? context.palette.negative
                      : context.palette.pending,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
