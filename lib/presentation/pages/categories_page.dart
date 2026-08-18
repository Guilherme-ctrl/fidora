import 'package:financeiro_ai/core/theme.dart';
import 'package:financeiro_ai/domain/analytics.dart';
import 'package:financeiro_ai/domain/models.dart';
import 'package:financeiro_ai/presentation/widgets/common.dart';
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
    final columns = width >= 1200
        ? 4
        : width >= 700
        ? 3
        : width >= 470
        ? 2
        : 1;
    final analytics = analyzePeriod(snapshot, period);
    return ListView(
      padding: EdgeInsets.fromLTRB(
        width < 600 ? 18 : 32,
        24,
        width < 600 ? 18 : 32,
        36,
      ),
      children: [
        PageHeading(
          title: 'Categorias',
          subtitle:
              'Cartão pela competência da fatura e conta pela data • ${period.label}.',
          action: width > 540
              ? Tooltip(
                  message: 'Criar uma categoria e definir seu orçamento',
                  child: FilledButton.icon(
                    onPressed: () => _showCreate(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Nova categoria'),
                  ),
                )
              : null,
        ),
        const SizedBox(height: 16),
        PeriodFilterBar(period: period, onChanged: onPeriodChanged),
        const SizedBox(height: 22),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.categories.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: columns == 1 ? 2.25 : 1.25,
          ),
          itemBuilder: (context, index) {
            final category = snapshot.categories[index];
            final spend = analytics.byCategory[category.name] ?? 0;
            final ratio =
                category.monthlyBudget == null || category.monthlyBudget == 0
                ? 0.0
                : (spend / category.monthlyBudget!).clamp(0, 1).toDouble();
            return Tooltip(
              message: 'Ver gastos, orçamento e saldo de ${category.name}',
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
                              child: Icon(category.icon, color: category.color),
                            ),
                            const Spacer(),
                            Tooltip(
                              message: 'Abrir detalhes da categoria',
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
                            color: ink.withValues(alpha: .58),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 10),
                        LinearProgressIndicator(
                          value: ratio,
                          minHeight: 7,
                          color: category.color,
                          backgroundColor: category.color.withValues(
                            alpha: .10,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
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

  void _showCreate(BuildContext context) => showDetailSheet(
    context,
    title: 'Nova categoria',
    description:
        'Categorias podem ter orçamento mensal e regras automáticas de estabelecimento.',
    child: const Text(
      'A criação será salva no Supabase e aparecerá nos filtros.',
    ),
  );

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
