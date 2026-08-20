import 'package:clock/clock.dart';
import 'package:financeiro_ai/core/theme.dart';
import 'package:financeiro_ai/core/breakpoints.dart';
import 'package:financeiro_ai/core/tokens.dart';
import 'package:financeiro_ai/core/typography.dart';
import 'package:financeiro_ai/domain/analytics.dart';
import 'package:financeiro_ai/domain/insights.dart';
import 'package:financeiro_ai/domain/invoice_forecast.dart';
import 'package:financeiro_ai/domain/models.dart';
import 'package:financeiro_ai/domain/narrative.dart';
import 'package:financeiro_ai/presentation/pages/review_queue_page.dart';
import 'package:financeiro_ai/presentation/widgets/common.dart';
import 'package:financeiro_ai/presentation/widgets/ledger.dart';
import 'package:financeiro_ai/presentation/cubits/catalog_cubits.dart';
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
          // Pequeno, ao lado do título: quanto do mês já passou. O anel só
          // cresce na fila, onde progresso é o assunto da tela.
          action: ProgressRing(
            value: _monthProgress(widget.period),
            child: Text(
              '${(_monthProgress(widget.period) * 100).round()}',
              style: context.type.labelCaps.copyWith(fontSize: 8),
            ),
          ),
        ),
        const SizedBox(height: Space.md),
        if (reviews > 0) _ReviewCallout(count: reviews, first: true),
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
        _Narrative(snapshot: widget.snapshot, period: widget.period, first: quiet),
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

class _ReviewCallout extends StatelessWidget {
  const _ReviewCallout({required this.count, required this.first});
  final int count;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final queue = context.watch<ReviewQueueCubit>().state;
    final item = queue.dataOrNull?.isNotEmpty ?? false ? queue.dataOrNull!.first : null;

    return RuledSection(
      first: first,
      title: count == 1
          ? '1 lançamento aguardando revisão'
          : '$count lançamentos aguardando revisão',
      trailing: MonoTag('fila', color: palette.accent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item != null) ...[
            Text(item.description ?? item.reason, style: context.type.bodyMd),
            const SizedBox(height: Space.xxs),
            Text(
              item.suggestedAction ?? item.reason,
              style: context.type.meta.copyWith(color: palette.inkSubtle),
            ),
            const SizedBox(height: Space.md),
          ] else ...[
            Text(
              'Cada item pergunta uma coisa e ensina uma regra: aprovar, '
              'corrigir a categoria, ou dizer "sempre assim" e nunca mais ver '
              'aquele estabelecimento na fila.',
              style: context.type.bodySm.copyWith(color: palette.inkMuted),
            ),
            const SizedBox(height: Space.md),
          ],
          InkButton(
            label: 'Abrir a fila',
            icon: Icons.arrow_forward_rounded,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ReviewQueuePage()),
            ),
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
