import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:financeiro_ai/features/review/presenter/cubits/review_cubits.dart';
import 'package:financeiro_ai/core/theme/theme.dart';
import 'package:financeiro_ai/core/theme/breakpoints.dart';
import 'package:financeiro_ai/core/theme/tokens.dart';
import 'package:financeiro_ai/core/theme/typography.dart';
import 'package:financeiro_ai/features/ledger/domain/entities/finance_period.dart';
import 'package:financeiro_ai/features/overview/domain/insights.dart';
import 'package:financeiro_ai/features/invoices/domain/invoice_forecast.dart';
import 'package:financeiro_ai/features/ledger/domain/entities/models.dart';
import 'package:financeiro_ai/features/overview/domain/narrative.dart';
import 'package:financeiro_ai/core/design_system/common.dart';
import 'package:financeiro_ai/core/design_system/ledger.dart';
import 'package:financeiro_ai/core/design_system/spark.dart';
import 'package:financeiro_ai/features/overview/domain/analytics.dart';
import 'package:financeiro_ai/features/overview/domain/comparison.dart';
import 'package:financeiro_ai/core/routing/routes.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// What needs you now.
///
/// The screen the product did not have. A new account used to land on an empty
/// dashboard, and the review queue — the one thing worth opening the app for on
/// an ordinary day — was three taps deep inside "Mais", even though the
/// snapshot has carried `pendingReviews` all along.
///
/// It answers one question in one order: what do I have to resolve? Reviews
/// first, because they are the loop that teaches the product; then an invoice
/// about to close, because that is money already spent; then a budget about to
/// break, because that is money not yet spent.
/// Quanto do período já correu. É o contexto que falta para saber se um gasto
/// está adiantado ou não — metade do orçamento no dia cinco é outra coisa.
double _monthProgress(FinancePeriod period) {
  final total = period.endExclusive.difference(period.start).inSeconds;
  if (total <= 0) return 0;
  final passed = clock.now().difference(period.start).inSeconds;
  return (passed / total).clamp(0.0, 1.0);
}

class TodayPage extends StatefulWidget {
  const TodayPage({
    super.key,
    required this.snapshot,
    required this.period,
    required this.onOpenInvoices,
  });

  final FinanceSnapshot snapshot;
  final FinancePeriod period;
  final VoidCallback onOpenInvoices;

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  @override
  void initState() {
    super.initState();
    // The queue used to be a FutureProvider, which fetched on first
    // watch. A cubit does not, so the screen asks — which keeps the
    // load off the app's first paint, where it never belonged.
    context.read<ReviewQueueCubit>().loadOnce();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final alerts = budgetAlerts(
      widget.snapshot,
      widget.period,
    ).where((alert) => alert.level != BudgetLevel.fine).toList();
    final closing = forecastInvoices(
      widget.snapshot,
    ).where((forecast) => forecast.daysRemaining <= 7).toList();
    final reviews = widget.snapshot.pendingReviews;
    final quiet = reviews == 0 && closing.isEmpty && alerts.isEmpty;

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
          title: 'Hoje',
          subtitle: quiet
              ? 'Nada exige sua atenção agora.'
              : 'O que precisa de você, em ordem.',
        ),
        const SizedBox(height: Space.md),
        _Pulse(
          snapshot: widget.snapshot,
          period: widget.period,
          onOpenInvoices: widget.onOpenInvoices,
        ),
        const SizedBox(height: Space.lg),
        if (reviews > 0) ...[
          _ReviewCallout(count: reviews, first: true),
          const SizedBox(height: Space.lg),
        ],
        for (final forecast in closing)
          _ClosingInvoice(
            forecast: forecast,
            first: reviews == 0 && forecast == closing.first,
            onOpen: widget.onOpenInvoices,
          ),
        for (final alert in alerts)
          _BudgetCallout(
            alert: alert,
            first: quiet
                ? false
                : reviews == 0 && closing.isEmpty && alert == alerts.first,
          ),
        _Narrative(
          snapshot: widget.snapshot,
          period: widget.period,
          first: quiet,
        ),
        if (quiet) ...[
          const SizedBox(height: Space.xl),
          Center(
            child: Text(
              'A fila está zerada.',
              style: context.type.bodySm.copyWith(color: palette.inkSubtle),
            ),
          ),
        ],
      ],
    );
  }
}

/// The queue, promoted.
///
/// It was a ruled section like any other, which put the product's one daily
/// action in the same visual weight as the paragraph below it. On the home
/// screen the queue is not information, it is the reason to be here.
class _ReviewCallout extends StatelessWidget {
  const _ReviewCallout({required this.count, required this.first});
  final int count;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final type = context.type;
    final queue = context.watch<ReviewQueueCubit>().state;
    final item = queue.dataOrNull?.isNotEmpty ?? false
        ? queue.dataOrNull!.first
        : null;

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.rule),
        borderRadius: BorderRadius.circular(Radii.lg),
        boxShadow: Depth.resting(palette.canvas),
      ),
      padding: const EdgeInsets.all(Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: palette.accentSoft,
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
                child: Text(
                  '$count',
                  style: type.titleMd.copyWith(color: palette.accent),
                ),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      count == 1
                          ? '1 lançamento na fila'
                          : '$count lançamentos na fila',
                      style: type.titleMd,
                    ),
                    Text(
                      'Precisam da sua atenção',
                      style: type.meta.copyWith(color: palette.inkSubtle),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          if (item != null) ...[
            Text(item.description ?? item.reason, style: type.bodyMd),
            const SizedBox(height: Space.xxs),
            Text(
              item.suggestedAction ?? item.reason,
              style: type.meta.copyWith(color: palette.inkSubtle),
            ),
            const SizedBox(height: Space.md),
          ] else ...[
            Text(
              'Cada item pergunta uma coisa e ensina uma regra: aprovar, '
              'corrigir a categoria, ou dizer "sempre assim" e nunca mais ver '
              'aquele estabelecimento na fila.',
              style: type.bodySm.copyWith(color: palette.inkMuted),
            ),
            const SizedBox(height: Space.md),
          ],
          InkButton(
            label: 'Abrir a fila',
            icon: Icons.arrow_forward_rounded,
            onPressed: () => context.go(Routes.review),
          ),
        ],
      ),
    );
  }
}

class _ClosingInvoice extends StatelessWidget {
  const _ClosingInvoice({
    required this.forecast,
    required this.first,
    required this.onOpen,
  });

  final InvoiceForecast forecast;
  final bool first;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return RuledSection(
      first: first,
      title: '${forecast.card.name} fecha em ${forecast.daysRemaining} dias',
      trailing: MonoTag('fatura', color: palette.pending),
      onTap: onOpen,
      tooltip: 'Abrir cartões e faturas',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionLabel('lançado'),
                    AmountText(
                      forecast.committed,
                      tone: MoneyTone.expense,
                      size: AmountSize.metric,
                      sign: false,
                      align: TextAlign.start,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionLabel('previsto ao fechar'),
                    AmountText(
                      forecast.total,
                      tone: MoneyTone.pending,
                      size: AmountSize.metric,
                      sign: false,
                      align: TextAlign.start,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          Text(
            'A previsão usa o ritmo dos ciclos anteriores deste cartão.',
            style: context.type.meta.copyWith(color: palette.inkSubtle),
          ),
        ],
      ),
    );
  }
}

class _BudgetCallout extends StatelessWidget {
  const _BudgetCallout({required this.alert, required this.first});
  final BudgetAlert alert;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final over = alert.ratio > 1;
    return RuledSection(
      first: first,
      title: over
          ? '${alert.category.name} passou da meta'
          : '${alert.category.name} chegou a ${(alert.ratio * 100).round()}% da meta',
      trailing: MonoTag(
        over ? 'estourado' : 'no limite',
        color: over ? palette.negative : palette.pending,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RuleBar(value: alert.ratio, over: over),
          const SizedBox(height: Space.xs),
          Text(
            '${currency.format(alert.spent)} de ${currency.format(alert.budget)}',
            style: context.type.amount.copyWith(color: palette.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _Narrative extends StatelessWidget {
  const _Narrative({
    required this.snapshot,
    required this.period,
    required this.first,
  });
  final FinanceSnapshot snapshot;
  final FinancePeriod period;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final insights = buildInsights(snapshot, period, money: currency.format);
    if (insights.isEmpty) return const SizedBox.shrink();
    final palette = context.palette;
    return RuledSection(
      first: first,
      title: 'O que mudou em ${period.label}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final insight in insights)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.xs),
              child: Text(
                insight.text,
                style: context.type.bodyMd.copyWith(color: palette.inkMuted),
              ),
            ),
        ],
      ),
    );
  }
}

/// The top of the home screen: three numbers and a shape.
///
/// The screen used to open on prose. Every fact it stated was true and useful —
/// and it still is, further down — but a person opening a finance app twice a
/// day is not reading, they are checking, and checking wants figures and a
/// line, not sentences. This is the block that answers "how am I doing" before
/// the eye reaches any word.
class _Pulse extends StatelessWidget {
  const _Pulse({
    required this.snapshot,
    required this.period,
    required this.onOpenInvoices,
  });

  final FinanceSnapshot snapshot;
  final FinancePeriod period;
  final VoidCallback onOpenInvoices;

  /// Spend accumulated day by day across the period.
  List<double> _cumulative() {
    final analytics = analyzePeriod(snapshot, period);
    final firstDay = DateTime(
      period.start.year,
      period.start.month,
      period.start.day,
    );
    final span = math.max(2, period.endExclusive.difference(firstDay).inDays);
    final daily = List<double>.filled(span, 0);
    for (final transaction in analytics.transactions) {
      if (transaction.expenseImpact <= 0) continue;
      final date = analyticsDate(transaction);
      final index = DateTime(
        date.year,
        date.month,
        date.day,
      ).difference(firstDay).inDays;
      if (index < 0 || index >= span) continue;
      daily[index] += transaction.expenseImpact;
    }
    var running = 0.0;
    return [for (final value in daily) running += value];
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final type = context.type;
    final analytics = analyzePeriod(snapshot, period);
    final elapsed = _monthProgress(period);
    final average = trailingMonthlyAverage(snapshot, period);
    final closing = forecastInvoices(snapshot).toList()
      ..sort((a, b) => a.daysRemaining.compareTo(b.daysRemaining));

    final budget = snapshot.categories
        .map((category) => category.monthlyBudget ?? 0)
        .fold<double>(0, (total, value) => total + value);
    // Against the budget when there is one, against the recent average when
    // there is not. The label says which, because a bar without its reference
    // is a decoration.
    final reference = budget > 0 ? budget : (average ?? 0);
    final referenceLabel = budget > 0
        ? 'de ${currency.format(budget)} em metas'
        : average == null
        ? 'sem base de comparação ainda'
        : 'média de ${currency.format(average)} nos últimos 3 meses';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: palette.surface,
            border: Border.all(color: palette.rule),
            borderRadius: BorderRadius.circular(Radii.lg),
            boxShadow: Depth.resting(palette.canvas),
          ),
          padding: const EdgeInsets.fromLTRB(
            Space.lg,
            Space.lg,
            Space.lg,
            Space.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionLabel('gasto até aqui'),
                        const SizedBox(height: Space.xxs),
                        AmountText(
                          analytics.expenses,
                          tone: MoneyTone.expense,
                          size: AmountSize.hero,
                          sign: false,
                          align: TextAlign.start,
                        ),
                        const SizedBox(height: Space.xxs),
                        Text(
                          referenceLabel,
                          style: type.meta.copyWith(color: palette.inkSubtle),
                        ),
                      ],
                    ),
                  ),
                  // O anel mede o *tempo*, não o dinheiro: é ele que diz se o
                  // número ao lado está adiantado ou não.
                  Tooltip(
                    message:
                        '${(elapsed * 100).round()}% de ${period.label} já passou',
                    child: ProgressRing(
                      value: elapsed,
                      size: 44,
                      stroke: 4,
                      child: Text(
                        '${(elapsed * 100).round()}%',
                        style: type.labelCaps.copyWith(
                          fontSize: 9,
                          color: palette.inkMuted,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (reference > 0) ...[
                const SizedBox(height: Space.sm),
                RuleBar(
                  value: analytics.expenses / reference,
                  over: analytics.expenses > reference,
                ),
              ],
              const SizedBox(height: Space.xs),
              Sparkline(values: _cumulative(), progress: elapsed),
            ],
          ),
        ),
        const SizedBox(height: Space.sm),
        Row(
          children: [
            Expanded(
              child: _Stat(
                label: 'entrou no período',
                value: analytics.income,
                tone: MoneyTone.income,
                note: analytics.income <= 0
                    ? 'nenhuma entrada lançada'
                    : '${analytics.savingsRate.round()}% do que entrou sobrou',
              ),
            ),
            const SizedBox(width: Space.sm),
            Expanded(
              child: closing.isEmpty
                  ? _Stat(
                      label: 'saldo do período',
                      value: analytics.balance,
                      tone: analytics.balance < 0
                          ? MoneyTone.negative
                          : MoneyTone.income,
                      note: 'entradas menos saídas',
                    )
                  : _Stat(
                      label: 'próxima fatura',
                      value: closing.first.total,
                      tone: MoneyTone.pending,
                      note: closing.first.daysRemaining == 0
                          ? '${closing.first.card.name} fecha hoje'
                          : '${closing.first.card.name} fecha em ${closing.first.daysRemaining} dias',
                      onTap: onOpenInvoices,
                    ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.tone,
    required this.note,
    this.onTap,
  });

  final String label;
  final double value;
  final MoneyTone tone;
  final String note;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final card = Container(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.rule),
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      padding: const EdgeInsets.all(Space.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SectionLabel(label),
          const SizedBox(height: Space.xxs),
          // Duas colunas num telefone de 390pt deixam ~150pt para um valor que
          // pode ter oito dígitos; sem isto, `R$ 9.800,00` quebra no meio do
          // zero. Encolher é melhor que quebrar, e melhor que truncar: o valor
          // continua inteiro.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AmountText(
              value,
              tone: tone,
              size: AmountSize.metric,
              sign: false,
              align: TextAlign.start,
            ),
          ),
          const SizedBox(height: Space.xxs),
          Text(
            note,
            style: context.type.meta.copyWith(color: palette.inkSubtle),
          ),
        ],
      ),
    );
    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.md),
      child: card,
    );
  }
}
