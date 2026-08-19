import 'package:financeiro_ai/core/theme.dart';
import 'package:financeiro_ai/domain/insights.dart';
import 'package:financeiro_ai/domain/models.dart';
import 'package:financeiro_ai/presentation/widgets/common.dart';
import 'package:flutter/material.dart';

class SubscriptionsPage extends StatelessWidget {
  const SubscriptionsPage({super.key, required this.snapshot});
  final FinanceSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final charges = detectRecurring(snapshot);
    final total = recurringMonthlyTotal(charges);
    final changed = charges.where((item) => item.priceChanged).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Assinaturas')),
      body: charges.isEmpty
          ? const _Empty()
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currency.format(total),
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'por mês em ${charges.length} ${charges.length == 1 ? 'cobrança recorrente' : 'cobranças recorrentes'}',
                          style: TextStyle(color: context.palette.inkMuted),
                        ),
                        const SizedBox(height: 14),
                        // The method is a heuristic, so it says so rather than
                        // presenting a guess as a fact.
                        Text(
                          'Detectadas pela repetição no seu histórico: mesmo '
                          'estabelecimento, em pelo menos três meses, por um '
                          'valor que se mantém. Parcelamentos ficam de fora.',
                          style: TextStyle(
                            color: context.palette.inkSubtle,
                            fontSize: 12.5,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (changed.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.palette.pending.withValues(alpha: .16),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.trending_up_rounded,
                          color: context.palette.pending,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            changed.length == 1
                                ? '${changed.single.merchant} mudou de valor.'
                                : '${changed.length} cobranças mudaram de valor.',
                            style: TextStyle(
                              color: context.palette.pending,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                ...charges.map((item) => _ChargeTile(charge: item)),
              ],
            ),
    );
  }
}

class _ChargeTile extends StatelessWidget {
  const _ChargeTile({required this.charge});
  final RecurringCharge charge;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  charge.merchant,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${charge.category} • ${charge.monthsSeen} meses • última em ${shortDate.format(charge.lastCharge)}',
                  style: TextStyle(
                    color: context.palette.inkMuted,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                currency.format(charge.monthlyCost),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              if (charge.priceChanged)
                Text(
                  '${charge.priceDelta > 0 ? '+' : '−'}${currency.format(charge.priceDelta.abs())}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: charge.priceDelta > 0
                        ? context.palette.negative
                        : context.palette.income,
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(28, 80, 28, 24),
    children: [
      Icon(
        Icons.subscriptions_rounded,
        size: 50,
        color: context.palette.accent,
      ),
      const SizedBox(height: 18),
      const Text(
        'Nenhuma cobrança recorrente',
        textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19),
      ),
      const SizedBox(height: 8),
      Text(
        'Uma cobrança aparece aqui depois de se repetir por três meses pelo '
        'mesmo valor. Com pouco histórico, ainda não há como distinguir uma '
        'assinatura de uma compra que se repetiu por acaso.',
        textAlign: TextAlign.center,
        style: TextStyle(color: context.palette.inkMuted, height: 1.45),
      ),
    ],
  );
}
