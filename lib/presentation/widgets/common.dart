import 'package:financeiro_ai/core/theme.dart';
import 'package:financeiro_ai/domain/analytics.dart';
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
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: context.palette.inkMuted),
            ),
          ],
        ),
      ),
      ?action,
    ],
  );
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.detail,
    this.onTap,
    this.tooltip,
    this.trendLabel,
    this.trendGood,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? detail;
  final VoidCallback? onTap;
  final String? tooltip;

  /// Optional movement against a baseline, e.g. “12% acima de julho”.
  final String? trendLabel;

  /// Whether the movement is good news. Null keeps the label neutral, which is
  /// the honest rendering when there is no baseline to judge against.
  final bool? trendGood;

  @override
  Widget build(BuildContext context) {
    final trend = trendLabel;
    final card = Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const Spacer(),
                  if (detail != null)
                    Text(
                      detail!,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: context.palette.inkMuted)),
              if (trend != null) ...[
                const SizedBox(height: 9),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      switch (trendGood) {
                        null => Icons.remove_rounded,
                        true => Icons.trending_down_rounded,
                        false => Icons.trending_up_rounded,
                      },
                      size: 15,
                      color: switch (trendGood) {
                        null => context.palette.inkSubtle,
                        true => context.palette.brand,
                        false => context.palette.danger,
                      },
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        trend,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: switch (trendGood) {
                            null => context.palette.inkSubtle,
                            true => context.palette.brand,
                            false => context.palette.danger,
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
    return tooltip == null
        ? card
        : Semantics(button: onTap != null, label: tooltip, child: card);
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.onTap,
    this.tooltip,
  });
  final String title;
  final Widget child;
  final Widget? trailing;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final card = Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  ?trailing,
                ],
              ),
              const SizedBox(height: 18),
              child,
            ],
          ),
        ),
      ),
    );
    return tooltip == null
        ? card
        : Semantics(button: onTap != null, label: tooltip, child: card);
  }
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
      lastDate: DateTime.now().add(const Duration(days: 1095)),
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
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      IconButton.filledTonal(
        tooltip: 'Voltar um mês',
        onPressed: () => onChanged(period.shiftMonth(-1)),
        icon: const Icon(Icons.chevron_left_rounded),
      ),
      Tooltip(
        message: 'Período usado por todos os indicadores desta tela',
        child: ActionChip(
          avatar: const Icon(Icons.calendar_month_rounded, size: 18),
          label: Text(
            period.label,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          onPressed: () => _pickRange(context),
        ),
      ),
      IconButton.filledTonal(
        tooltip: 'Avançar um mês',
        onPressed: () => onChanged(period.shiftMonth(1)),
        icon: const Icon(Icons.chevron_right_rounded),
      ),
      TextButton(
        onPressed: () => onChanged(FinancePeriod.month(DateTime.now())),
        child: const Text('Este mês'),
      ),
      OutlinedButton.icon(
        onPressed: () => _pickRange(context),
        icon: const Icon(Icons.date_range_rounded),
        label: const Text('Período'),
      ),
      const Tooltip(
        message:
            'Compras no cartão entram pela competência da fatura. Conta, Pix e débito entram pela data da movimentação.',
        child: Chip(
          avatar: Icon(Icons.credit_card_rounded, size: 17),
          label: Text('Cartão por fatura'),
        ),
      ),
    ],
  );
}

Future<void> showDetailSheet(
  BuildContext context, {
  required String title,
  required String description,
  required Widget child,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) => SafeArea(
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .82,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(color: context.palette.inkMuted),
            ),
            const SizedBox(height: 22),
            child,
          ],
        ),
      ),
    ),
  ),
);

class DetailValue extends StatelessWidget {
  const DetailValue({super.key, required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: TextStyle(color: context.palette.inkMuted)),
        ),
        const SizedBox(width: 16),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
      ],
    ),
  );
}
