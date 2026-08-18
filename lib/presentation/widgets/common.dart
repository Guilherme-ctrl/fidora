import 'package:financeiro_ai/core/theme.dart';
import 'package:financeiro_ai/domain/analytics.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
final shortDate = DateFormat('dd MMM', 'pt_BR');
final monthName = DateFormat('MMMM', 'pt_BR');
final monthYear = DateFormat('MMMM yyyy', 'pt_BR');

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
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: ink.withValues(alpha: .62),
              ),
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
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? detail;
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
              Text(label, style: TextStyle(color: ink.withValues(alpha: .6))),
            ],
          ),
        ),
      ),
    );
    return tooltip == null ? card : Tooltip(message: tooltip!, child: card);
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
    return tooltip == null ? card : Tooltip(message: tooltip!, child: card);
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
      Tooltip(
        message: 'Voltar um mês',
        child: IconButton.filledTonal(
          onPressed: () => onChanged(period.shiftMonth(-1)),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
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
      Tooltip(
        message: 'Avançar um mês',
        child: IconButton.filledTonal(
          onPressed: () => onChanged(period.shiftMonth(1)),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ),
      Tooltip(
        message: 'Mostrar o mês atual',
        child: TextButton(
          onPressed: () => onChanged(FinancePeriod.month(DateTime.now())),
          child: const Text('Este mês'),
        ),
      ),
      Tooltip(
        message: 'Escolher datas inicial e final livremente',
        child: OutlinedButton.icon(
          onPressed: () => _pickRange(context),
          icon: const Icon(Icons.date_range_rounded),
          label: const Text('Período'),
        ),
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
              style: TextStyle(color: ink.withValues(alpha: .65)),
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
          child: Text(
            label,
            style: TextStyle(color: ink.withValues(alpha: .62)),
          ),
        ),
        const SizedBox(width: 16),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
      ],
    ),
  );
}
