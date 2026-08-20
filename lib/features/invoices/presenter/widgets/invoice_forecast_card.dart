import 'package:financeiro_ai/core/theme/theme.dart';
import 'package:financeiro_ai/features/invoices/domain/invoice_forecast.dart';
import 'package:financeiro_ai/features/ledger/domain/entities/models.dart';
import 'package:financeiro_ai/core/design_system/common.dart';
import 'package:financeiro_ai/core/design_system/ledger.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final _monthName = DateFormat('MMMM', 'pt_BR');
final _dayMonth = DateFormat('d/MM', 'pt_BR');

/// What each open invoice is heading towards.
///
/// The whole point is to separate the parts by how much they can be trusted,
/// so the split into "já lançado / parcelas / estimativa" is the design, not
/// decoration. A single confident total would be the wrong answer even when
/// the arithmetic is right.
class InvoiceForecastCard extends StatelessWidget {
  const InvoiceForecastCard({super.key, required this.snapshot, this.now});

  final FinanceSnapshot snapshot;

  /// Injectable so a test can pin the date instead of racing the clock.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final forecasts = forecastInvoices(snapshot, now: now);
    if (forecasts.isEmpty) return const SizedBox.shrink();

    return RuledSection(
      title: 'Previsão de fechamento',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final forecast in forecasts) _ForecastRow(forecast: forecast),
          const SizedBox(height: 4),
          Text(
            'A estimativa vem do ritmo do próprio cartão nos ciclos '
            'anteriores. Parcelas já contratadas entram inteiras, porque não '
            'dependem de você gastar mais.',
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
}

class _ForecastRow extends StatelessWidget {
  const _ForecastRow({required this.forecast});
  final InvoiceForecast forecast;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final month = _monthName.format(forecast.competence);

    return Semantics(
      label: _semanticLabel(month),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 18),
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
                      Text(
                        '${forecast.card.name} · $month',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _timing(),
                        style: TextStyle(
                          color: palette.inkSubtle,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Expanded on the left does not save the row when the total
                // alone is wider than the card: at 2x text it overflowed by
                // 42px. Flexible lets the amount wrap.
                Flexible(
                  child: Text(
                    currency.format(forecast.total),
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 19,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _Bar(forecast: forecast),
            const SizedBox(height: 8),
            Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                _Part(
                  label: 'já lançado',
                  value: forecast.committed,
                  color: palette.accent,
                ),
                if (forecast.scheduled > 0)
                  _Part(
                    label: 'parcelas',
                    value: forecast.scheduled,
                    color: palette.pending,
                  ),
                if (forecast.estimated > 0)
                  _Part(
                    label: 'estimativa',
                    value: forecast.estimated,
                    color: palette.inkSubtle,
                  ),
              ],
            ),
            if (!forecast.hasBaseline && !forecast.isClosed) ...[
              const SizedBox(height: 6),
              Text(
                'Sem ciclo anterior para comparar — este número é só o que já '
                'está lançado, não uma projeção.',
                style: TextStyle(
                  color: palette.inkSubtle,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _timing() {
    if (forecast.isClosed) {
      return 'Fechada em ${_dayMonth.format(forecast.closingDate)}';
    }
    final days = forecast.daysRemaining;
    final observed = forecast.daysObserved;
    final base = days == 1
        ? 'Fecha amanhã'
        : 'Fecha em $days dias, ${_dayMonth.format(forecast.closingDate)}';
    // Saying how thin the evidence is costs one clause and stops a rate drawn
    // from a single fortnight from reading like a settled trend.
    return observed == 0 ? base : '$base · base de $observed dias';
  }

  String _semanticLabel(String month) {
    final parts = <String>[
      'Fatura de $month do cartão ${forecast.card.name}',
      'previsão ${currency.format(forecast.total)}',
      '${currency.format(forecast.committed)} já lançado',
    ];
    if (forecast.scheduled > 0) {
      parts.add('${currency.format(forecast.scheduled)} em parcelas');
    }
    if (forecast.estimated > 0) {
      parts.add('${currency.format(forecast.estimated)} estimado');
    }
    return parts.join(', ');
  }
}

/// The three parts to scale, so the guess is visibly a guess.
class _Bar extends StatelessWidget {
  const _Bar({required this.forecast});
  final InvoiceForecast forecast;

  @override
  Widget build(BuildContext context) {
    final total = forecast.total;
    if (total <= 0) return const SizedBox.shrink();
    final palette = context.palette;

    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: SizedBox(
        height: 8,
        child: Row(
          children: [
            if (forecast.committed > 0)
              Expanded(
                flex: (forecast.committed / total * 1000).round(),
                child: ColoredBox(color: palette.accent),
              ),
            if (forecast.scheduled > 0)
              Expanded(
                flex: (forecast.scheduled / total * 1000).round(),
                child: ColoredBox(color: palette.pending),
              ),
            if (forecast.estimated > 0)
              Expanded(
                flex: (forecast.estimated / total * 1000).round(),
                // Hatched rather than solid: the estimate is the one part
                // nobody has actually spent yet.
                child: ColoredBox(
                  color: palette.inkSubtle.withValues(alpha: .28),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Part extends StatelessWidget {
  const _Part({required this.label, required this.value, required this.color});
  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      // The legend sits in a Wrap, so its own row must be able to give: at
      // 1.3x text the amount plus the label overflowed by 30px.
      Flexible(
        child: Text(
          '${currency.format(value)} $label',
          style: TextStyle(
            fontSize: 12.5,
            color: context.palette.inkMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );
}
