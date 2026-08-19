import 'package:financeiro_ai/core/theme.dart';
import 'package:financeiro_ai/domain/analytics.dart';
import 'package:financeiro_ai/domain/models.dart';
import 'package:financeiro_ai/domain/narrative.dart';
import 'package:financeiro_ai/presentation/widgets/common.dart';
import 'package:flutter/material.dart';

/// The few things that actually changed, in sentences.
///
/// It removes itself when it has nothing to say. An insights panel that pads
/// itself with "seus gastos estão normais" trains the reader to skip it, and
/// then it is not there on the month something is wrong.
class InsightsCard extends StatelessWidget {
  const InsightsCard({
    super.key,
    required this.snapshot,
    required this.period,
    this.now,
  });

  final FinanceSnapshot snapshot;
  final FinancePeriod period;

  /// Injectable so a test can pin the date instead of racing the clock.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final insights = buildInsights(
      snapshot,
      period,
      money: currency.format,
      now: now,
    );
    if (insights.isEmpty) return const SizedBox.shrink();

    // The gap belongs to the card rather than to the page: a fixed SizedBox
    // after it would leave a double space on the months it has nothing to say.
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: _panel(context, insights),
    );
  }

  Widget _panel(BuildContext context, List<Insight> insights) => SectionCard(
    title: 'O que mudou',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final insight in insights) _InsightRow(insight: insight),
        Text(
          'Comparações com os meses anteriores deste mesmo histórico. '
          'Nada aqui é estimado por texto: todo número sai das mesmas '
          'contas das outras telas.',
          style: TextStyle(
            color: context.palette.inkSubtle,
            fontSize: 12,
            height: 1.4,
          ),
        ),
      ],
    ),
  );
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({required this.insight});
  final Insight insight;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // The key carries the tone, so a test can assert the direction without
    // naming the glyph — the icon set is a design decision and is expected to
    // change; what the row means is not.
    final (icon, color, key) = switch (insight.tone) {
      InsightTone.warning => (
        Icons.trending_up_rounded,
        palette.danger,
        const Key('insight-tone-warning'),
      ),
      InsightTone.good => (
        Icons.trending_down_rounded,
        palette.brand,
        const Key('insight-tone-good'),
      ),
      InsightTone.neutral => (
        Icons.info_outline_rounded,
        palette.inkMuted,
        const Key('insight-tone-neutral'),
      ),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            key: key,
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(9),
            ),
            // The icon repeats what the sentence already says, so it carries no
            // label of its own — a screen reader would otherwise read the
            // direction twice.
            child: ExcludeSemantics(child: Icon(icon, size: 16, color: color)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              insight.text,
              style: const TextStyle(fontSize: 14, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}
