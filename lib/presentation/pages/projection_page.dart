import 'dart:math' as math;

import 'package:financeiro_ai/core/breakpoints.dart';
import 'package:financeiro_ai/core/theme.dart';
import 'package:financeiro_ai/core/tokens.dart';
import 'package:financeiro_ai/domain/analytics.dart';
import 'package:financeiro_ai/domain/models.dart';
import 'package:financeiro_ai/presentation/widgets/common.dart';
import 'package:financeiro_ai/presentation/widgets/ledger.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class ProjectionPage extends StatelessWidget {
  const ProjectionPage({
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
    final projection = buildProjection(snapshot, period);
    final projectedTotal = projection.fold<double>(
      0,
      (sum, item) => sum + item.total,
    );
    final installments = projection.fold<double>(
      0,
      (sum, item) => sum + item.installments,
    );
    final average = projection.isEmpty
        ? 0.0
        : projectedTotal / projection.length;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        Breakpoint.of(context).gutter,
        Space.xl,
        Breakpoint.of(context).gutter,
        Space.xxxl,
      ),
      children: [
        const PageHeading(
          title: 'Projeção financeira',
          subtitle:
              'Faturas, parcelas e conta projetadas para os próximos seis meses.',
        ),
        const SizedBox(height: 18),
        PeriodFilterBar(period: period, onChanged: onPeriodChanged),
        const SizedBox(height: 20),
        // A fixed `childAspectRatio` cannot grow with the text, which is what
        // overflowed this page at 1.3x. Rows of intrinsic height can.
        LedgerTileRow(
          columns: width >= 1100
              ? 3
              : width >= 650
              ? 2
              : 1,
          tiles: [
            LedgerTile(
              label: 'Média mensal projetada',
              value: currency.format(average),
              detail: 'próximos 6 meses',
              tooltip: 'Abrir a composição da média projetada',
              onTap: () => _showProjectionComposition(context, projection),
            ),
            LedgerTile(
              label: 'Parcelas futuras',
              value: currency.format(installments),
              detail: '${_activeInstallments(snapshot)} compromissos',
              tooltip: 'Ver as parcelas que ainda impactarão suas faturas',
              onTap: () => _showInstallments(context, snapshot),
            ),
            LedgerTile(
              label: 'Total projetado',
              value: currency.format(projectedTotal),
              detail: '6 meses',
              tooltip: 'Ver o total acumulado da projeção',
              onTap: () => _showProjectionComposition(context, projection),
            ),
          ],
        ),
        const SizedBox(height: 14),
        RuledSection(
          title: 'Próximos seis meses',
          tooltip: 'Clique para ver os valores mensais em detalhes',
          onTap: () => _showProjectionComposition(context, projection),
          trailing: Tooltip(
            message:
                'Estimativa baseada no ritmo do período escolhido mais parcelas futuras',
            child: Icon(
              Icons.info_outline_rounded,
              color: context.palette.inkSubtle,
            ),
          ),
          child: SizedBox(
            height:
                300 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.4),
            child: _ProjectionChart(projection: projection),
          ),
        ),
        const SizedBox(height: 14),
        _GoalsOutlook(snapshot: snapshot, period: period),
      ],
    );
  }

  int _activeInstallments(FinanceSnapshot snapshot) => snapshot.transactions
      .where(
        (item) =>
            item.status != TransactionStatus.ignored &&
            item.isInstallment &&
            (item.installmentCurrent ?? 0) < (item.installmentTotal ?? 0),
      )
      .length;

  void _showProjectionComposition(
    BuildContext context,
    List<MonthlyProjection> projection,
  ) => showDetailSheet(
    context,
    title: 'Composição da projeção',
    description:
        'A base mensaliza o ritmo do período selecionado. As parcelas são compromissos já conhecidos e entram separadamente.',
    child: Column(
      children: projection
          .map(
            (item) => Column(
              children: [
                DetailValue(
                  label: monthYear.format(item.month),
                  value: currency.format(item.total),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Text(
                    'Base ${currency.format(item.baseline)} + parcelas ${currency.format(item.installments)}',
                    style: TextStyle(color: context.palette.inkMuted),
                  ),
                ),
              ],
            ),
          )
          .toList(),
    ),
  );

  void _showInstallments(BuildContext context, FinanceSnapshot snapshot) {
    final items =
        snapshot.transactions
            .where(
              (item) =>
                  item.status != TransactionStatus.ignored &&
                  item.isInstallment &&
                  (item.installmentCurrent ?? 0) < (item.installmentTotal ?? 0),
            )
            .toList()
          ..sort(
            (a, b) => (b.installmentTotal! - b.installmentCurrent!).compareTo(
              a.installmentTotal! - a.installmentCurrent!,
            ),
          );
    showDetailSheet(
      context,
      title: 'Parcelas futuras',
      description:
          'Compromissos parcelados encontrados no histórico. Registros repetidos de faturas anteriores podem representar a evolução da mesma compra.',
      child: Column(
        children: items
            .take(30)
            .map(
              (item) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  item.merchant,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '${item.installmentCurrent}/${item.installmentTotal} • final ${item.cardLastFour}',
                ),
                trailing: Text(
                  currency.format(item.amount),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ProjectionChart extends StatelessWidget {
  const _ProjectionChart({required this.projection});
  final List<MonthlyProjection> projection;

  @override
  Widget build(BuildContext context) {
    final maxTotal = projection.fold<double>(
      0,
      (maxValue, item) => math.max(maxValue, item.total),
    );
    return BarChart(
      BarChartData(
        maxY: maxTotal <= 0 ? 1 : maxTotal * 1.18,
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
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= projection.length) {
                  return const SizedBox();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    monthName.format(projection[index].month).substring(0, 3),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
              '${monthYear.format(projection[group.x].month)}\n${currency.format(rod.toY)}',
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
            ),
          ),
        ),
        barGroups: projection.indexed
            .map(
              (entry) => BarChartGroupData(
                x: entry.$1,
                barRods: [
                  BarChartRodData(
                    toY: entry.$2.total,
                    width: 24,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(8),
                    ),
                    gradient: LinearGradient(
                      colors: [context.palette.accent, const Color(0xFF5D65A8)],
                    ),
                  ),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}

class _GoalsOutlook extends StatelessWidget {
  const _GoalsOutlook({required this.snapshot, required this.period});
  final FinanceSnapshot snapshot;
  final FinancePeriod period;

  @override
  Widget build(BuildContext context) {
    final analytics = analyzePeriod(snapshot, period);
    final categories = snapshot.categories
        .where((item) => item.monthlyBudget != null && item.monthlyBudget! > 0)
        .toList();
    return RuledSection(
      title: 'Metas versus realizado',
      tooltip: 'Abrir a comparação de cada orçamento no período',
      onTap: () => showDetailSheet(
        context,
        title: 'Metas versus realizado',
        description:
            'Para períodos mensais, o orçamento é comparado ao gasto real da categoria.',
        child: Column(
          children: categories
              .map(
                (category) => DetailValue(
                  label: category.name,
                  value:
                      '${currency.format(analytics.byCategory[category.name] ?? 0)} / ${currency.format(category.monthlyBudget)}',
                ),
              )
              .toList(),
        ),
      ),
      child: Column(
        children: categories.map((category) {
          final actual = analytics.byCategory[category.name] ?? 0;
          final ratio = (actual / category.monthlyBudget!).clamp(0.0, 1.0);
          final over = actual > category.monthlyBudget!;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        category.name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    // Two amounts side by side need more than a narrow card
                    // can give: the pair overflowed by 28px at 390pt. Flexible
                    // lets it wrap instead of clipping a value.
                    Flexible(
                      child: Text(
                        '${currency.format(actual)} de ${currency.format(category.monthlyBudget)}',
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          color: over
                              ? context.palette.negative
                              : context.palette.income,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                RuleBar(
                  value: ratio,
                  over: over,
                  color: context.palette.income,
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
