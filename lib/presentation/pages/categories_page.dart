import 'package:financeiro_ai/core/breakpoints.dart';
import 'package:financeiro_ai/core/theme.dart';
import 'package:financeiro_ai/core/typography.dart';
import 'package:financeiro_ai/core/tokens.dart';
import 'package:financeiro_ai/domain/analytics.dart';
import 'package:financeiro_ai/domain/models.dart';
import 'package:financeiro_ai/presentation/widgets/category_form_sheet.dart';
import 'package:financeiro_ai/presentation/widgets/common.dart';
import 'package:financeiro_ai/presentation/widgets/ledger.dart';
import 'package:financeiro_ai/presentation/category_visuals.dart';
import 'package:flutter/material.dart';

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({
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
    final layout = Breakpoint.of(context);
    final columns = switch (layout) {
      Breakpoint.large => 4,
      Breakpoint.expanded => 3,
      Breakpoint.medium => 2,
      Breakpoint.compact => width >= 470 ? 2 : 1,
    };
    final analytics = analyzePeriod(snapshot, period);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        layout.gutter,
        Space.xl,
        layout.gutter,
        Space.xxxl,
      ),
      children: [
        PageHeading(
          title: 'Categorias',
          subtitle:
              'Cartão pela competência da fatura e conta pela data • ${period.label}.',
          action: width > 540
              ? Semantics(
                  label: 'Criar uma categoria e definir seu orçamento',
                  child: FilledButton.icon(
                    onPressed: () => editCategory(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Nova categoria'),
                  ),
                )
              : null,
        ),
        const SizedBox(height: 18),
        if (snapshot.categories.isEmpty)
          // The only list on the six tabs that had nothing to say when it was
          // empty. A blank screen reads as a failure; this says what will
          // appear here and offers the one action that fills it.
          _EmptyCategories(onCreate: () => editCategory(context))
        else
          _CategoryGrid(
            columns: columns,
            count: snapshot.categories.length,
            builder: (context, index) {
              final category = snapshot.categories[index];
              final spend = analytics.byCategory[category.name] ?? 0;
              final ratio =
                  category.monthlyBudget == null || category.monthlyBudget == 0
                  ? 0.0
                  : (spend / category.monthlyBudget!).clamp(0, 1).toDouble();
              return Semantics(
                label: 'Ver gastos, orçamento e saldo de ${category.name}',
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () =>
                        _showCategory(context, category, spend, analytics),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: category.color.withValues(alpha: .15),
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                child: Icon(
                                  category.icon,
                                  color: category.color,
                                ),
                              ),
                              const Spacer(),
                              Semantics(
                                label: 'Abrir detalhes da categoria',
                                child: Icon(
                                  Icons.more_horiz,
                                  color: Colors.black26,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            category.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            category.monthlyBudget == null
                                ? '${currency.format(spend)} no período'
                                : '${currency.format(spend)} de ${currency.format(category.monthlyBudget)}',
                            style: TextStyle(
                              color: context.palette.inkMuted,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 10),
                          RuleBar(value: ratio, color: category.color),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  void _showCategory(
    BuildContext context,
    FinanceCategory category,
    double spend,
    PeriodAnalytics analytics,
  ) {
    final budget = category.monthlyBudget;
    final transactions = analytics.transactions
        .where((item) => item.category == category.name)
        .toList();
    showDetailSheet(
      context,
      title: category.name,
      description: '${transactions.length} lançamentos em ${period.label}.',
      child: Column(
        children: [
          DetailValue(label: 'Realizado', value: currency.format(spend)),
          if (budget != null)
            DetailValue(label: 'Meta mensal', value: currency.format(budget)),
          if (budget != null)
            DetailValue(
              label: spend <= budget ? 'Disponível' : 'Excedente',
              value: currency.format((budget - spend).abs()),
            ),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                editCategory(context, existing: category);
              },
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Editar categoria'),
            ),
          ),
          const Divider(height: 28),
          ...transactions
              .take(30)
              .map(
                (item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    item.merchant,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    isCardTransaction(item) && item.competence != null
                        ? 'Compra ${shortDate.format(item.date)} • fatura ${monthName.format(item.competence!)}'
                        : shortDate.format(item.date),
                  ),
                  trailing: Text(
                    currency.format(item.amount),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

/// Rows of intrinsic height, in place of a grid with a fixed cell ratio.
class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({
    required this.columns,
    required this.count,
    required this.builder,
  });

  final int columns;
  final int count;
  final Widget Function(BuildContext, int) builder;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var start = 0; start < count; start += columns) {
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var slot = 0; slot < columns; slot++) ...[
                if (slot > 0) const SizedBox(width: Space.sm),
                Expanded(
                  child: start + slot < count
                      ? builder(context, start + slot)
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: Space.sm),
          rows[i],
        ],
      ],
    );
  }
}

/// What the categories screen says before there are any.
class _EmptyCategories extends StatelessWidget {
  const _EmptyCategories({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Space.huge),
    child: Column(
      children: [
        const SectionLabel('nada por aqui ainda'),
        const SizedBox(height: Space.sm),
        Text(
          'As categorias organizam para onde o dinheiro vai.',
          textAlign: TextAlign.center,
          style: context.type.bodyMd,
        ),
        const SizedBox(height: Space.xxs),
        Text(
          'Cada uma pode ter um orçamento mensal, e é ele que alimenta os '
          'avisos de meta em Hoje.',
          textAlign: TextAlign.center,
          style: context.type.bodySm.copyWith(color: context.palette.inkMuted),
        ),
        const SizedBox(height: Space.lg),
        InkButton(
          label: 'Criar a primeira categoria',
          icon: Icons.add_rounded,
          onPressed: onCreate,
        ),
      ],
    ),
  );
}
