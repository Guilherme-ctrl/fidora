import 'package:clock/clock.dart';
import 'package:financeiro_ai/core/theme.dart';
import 'package:financeiro_ai/core/tokens.dart';
import 'package:financeiro_ai/core/typography.dart';
import 'package:financeiro_ai/domain/analytics.dart';
import 'package:financeiro_ai/presentation/widgets/ledger.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// The money formatter, resolved from `profiles.currency` at startup rather
/// than hardcoded to reais.
///
/// It is a mutable top-level on purpose: the alternative was threading a
/// formatter through roughly forty call sites for a value that is fixed per
/// account and settled before the first frame of data. [configureCurrency] is
/// idempotent and called from the shell as each snapshot arrives.
NumberFormat currency = _formatterFor('BRL');

/// Locale drives grouping and decimal separators; the symbol has to be given
/// explicitly, because intl falls back to the ISO code otherwise — which is how
/// a first attempt at this printed "BRL 1.234,50" across the whole app.
const _currencyFormats = <String, (String locale, String symbol)>{
  'BRL': ('pt_BR', r'R$'),
  'USD': ('en_US', r'$'),
  'EUR': ('de_DE', '€'),
  'GBP': ('en_GB', '£'),
  'ARS': ('es_AR', r'$'),
  'CLP': ('es_CL', r'$'),
  'MXN': ('es_MX', r'$'),
  'JPY': ('ja_JP', '¥'),
};

NumberFormat _formatterFor(String code) {
  final normalized = code.toUpperCase();
  final format = _currencyFormats[normalized];
  // An unmapped code still formats correctly, just with the code as its symbol.
  return format == null
      ? NumberFormat.currency(symbol: '$normalized ')
      : NumberFormat.currency(locale: format.$1, symbol: format.$2);
}

String _configuredCurrency = 'BRL';

void configureCurrency(String code) {
  final normalized = code.trim().toUpperCase();
  if (normalized.isEmpty || normalized == _configuredCurrency) return;
  _configuredCurrency = normalized;
  currency = _formatterFor(normalized);
}

final shortDate = DateFormat('dd MMM', 'pt_BR');
final monthName = DateFormat('MMMM', 'pt_BR');
final monthYear = DateFormat('MMMM yyyy', 'pt_BR');
final longDate = DateFormat("d 'de' MMMM 'de' y", 'pt_BR');

/// Axis labels need the magnitude, not the cents.
final compactCurrency = NumberFormat.compactCurrency(
  locale: 'pt_BR',
  symbol: r'R$',
  decimalDigits: 0,
);

class PageHeading extends StatelessWidget {
  const PageHeading({
    super.key,
    required this.title,
    required this.subtitle,
    this.action,
  });
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Space.xs),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.type.titleLg),
              const SizedBox(height: Space.xxs),
              // The subtitles in this product are sentences, not eyebrows.
              // Setting one in spaced small caps — as the prototype does with
              // a short date — made a line three times wider and said the
              // wrong thing about it.
              Text(
                subtitle,
                style: context.type.bodySm.copyWith(
                  color: context.palette.inkMuted,
                ),
              ),
            ],
          ),
        ),
        ?action,
      ],
    ),
  );
}

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

/// The detail sheet, now responsive.
///
/// Every call site kept its shape; what changed is where the panel comes from.
/// On a desktop it slides in from the right and leaves the list behind it, so
/// the number someone is checking stays on screen.
Future<void> showDetailSheet(
  BuildContext context, {
  required String title,
  required String description,
  required Widget child,
}) => showResponsiveSheet<void>(
  context,
  title: title,
  description: description,
  builder: (_) => child,
);

class DetailValue extends StatelessWidget {
  const DetailValue({super.key, required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Space.xs),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(child: SectionLabel(label)),
        const SizedBox(width: Space.md),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: context.type.amount,
          ),
        ),
      ],
    ),
  );
}
