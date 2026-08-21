import 'package:clock/clock.dart';
import 'package:financeiro_ai/core/design_system/ledger.dart';
import 'package:financeiro_ai/core/theme/typography.dart';
import 'package:financeiro_ai/core/theme/theme.dart';
import 'package:financeiro_ai/core/theme/tokens.dart';
import 'package:financeiro_ai/features/ledger/domain/entities/finance_period.dart';
import 'package:flutter/material.dart';

/// Choosing the window the whole app reports on.
///
/// It sat in `core/design_system`, which is what made the design system import
/// a feature's domain — `core` may not depend on `features`, and a control
/// that knows what a `FinancePeriod` is was never generic visual
/// infrastructure. It is shared between features, which is what
/// `features/shared` is for.

class PeriodFilterBar extends StatelessWidget {
  const PeriodFilterBar({
    super.key,
    required this.period,
    required this.onChanged,
  });

  final FinancePeriod period;
  final ValueChanged<FinancePeriod> onChanged;

  Future<void> _pickRange(BuildContext context) async {
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: clock.now().add(const Duration(days: 1095)),
      initialDateRange: DateTimeRange(
        start: period.start,
        end: period.endInclusive,
      ),
      locale: const Locale('pt', 'BR'),
      helpText: 'Selecionar período financeiro',
      saveText: 'Aplicar',
    );
    if (result != null) {
      onChanged(FinancePeriod(start: result.start, endInclusive: result.end));
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // One outlined group instead of six loose Material pieces — two filled
    // tonal icon buttons, an action chip, a text button, an outlined button and
    // a plain chip, each with its own shape.
    Widget segment(Widget child, {VoidCallback? onTap, String? tooltip}) {
      final button = InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.sm,
            vertical: Space.xxs + 2,
          ),
          child: child,
        ),
      );
      return tooltip == null
          ? button
          : Tooltip(message: tooltip, child: button);
    }

    final divider = Container(
      width: Strokes.hairline,
      height: 26,
      color: palette.ruleStrong,
    );

    return Wrap(
      spacing: Space.xs,
      runSpacing: Space.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Bounded so the group can shrink rather than push past the page.
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: IntrinsicHeight(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: palette.ruleStrong),
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
              clipBehavior: Clip.antiAlias,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  segment(
                    const Icon(Icons.chevron_left_rounded, size: 18),
                    onTap: () => onChanged(period.shiftMonth(-1)),
                    tooltip: 'Voltar um mês',
                  ),
                  divider,
                  // The label is the only segment that can give: on a 375pt
                  // phone the four fixed segments together are wider than the
                  // screen.
                  Flexible(
                    child: segment(
                      Text(
                        period.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.type.bodySm.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () => _pickRange(context),
                      tooltip:
                          'Período usado por todos os indicadores desta tela',
                    ),
                  ),
                  divider,
                  segment(
                    const Icon(Icons.chevron_right_rounded, size: 18),
                    onTap: () => onChanged(period.shiftMonth(1)),
                    tooltip: 'Avançar um mês',
                  ),
                  divider,
                  segment(
                    Text('Este mês', style: context.type.bodySm),
                    onTap: () => onChanged(FinancePeriod.month(clock.now())),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Tooltip(
          message:
              'Compras no cartão entram pela competência da fatura. Conta, Pix e débito entram pela data da movimentação.',
          child: MonoTag('cartão por fatura', icon: Icons.credit_card_rounded),
        ),
      ],
    );
  }
}
