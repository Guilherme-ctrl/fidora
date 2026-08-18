import 'package:financeiro_ai/core/theme.dart';
import 'package:financeiro_ai/domain/analytics.dart';
import 'package:financeiro_ai/domain/comparison.dart';
import 'package:financeiro_ai/domain/invoice_status.dart';
import 'package:financeiro_ai/domain/models.dart';
import 'package:financeiro_ai/presentation/widgets/common.dart';
import 'package:financeiro_ai/application/providers.dart';
import 'package:financeiro_ai/domain/transaction_draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CardsPage extends StatelessWidget {
  const CardsPage({super.key, required this.snapshot, required this.period});
  final FinanceSnapshot snapshot;
  final FinancePeriod period;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        width < 600 ? 18 : 32,
        24,
        width < 600 ? 18 : 32,
        36,
      ),
      children: [
        PageHeading(
          title: 'Cartões e faturas',
          subtitle: 'Quanto ainda dá para usar, quando fecha e quando vence.',
          action: width > 560
              ? Semantics(
                  label: 'Cadastrar um novo cartão de crédito',
                  child: FilledButton.icon(
                    onPressed: () => showDetailSheet(
                      context,
                      title: 'Adicionar cartão',
                      description:
                          'Cadastre banco, final, fechamento, vencimento e limite.',
                      child: const Text(
                        'O formulário será salvo no Supabase e usado pelo Atalho.',
                      ),
                    ),
                    icon: const Icon(Icons.add_card),
                    label: const Text('Adicionar cartão'),
                  ),
                )
              : null,
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            final split = constraints.maxWidth >= 850;
            final cards = Column(
              children: snapshot.cards
                  .map(
                    (card) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _CreditCardView(
                        card: card,
                        usage: cardUsage(snapshot, card),
                      ),
                    ),
                  )
                  .toList(),
            );
            final invoices = _InvoicesList(snapshot: snapshot, period: period);
            return split
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: cards),
                      const SizedBox(width: 14),
                      Expanded(child: invoices),
                    ],
                  )
                : Column(children: [cards, invoices]);
          },
        ),
      ],
    );
  }
}

class _CreditCardView extends StatelessWidget {
  const _CreditCardView({required this.card, required this.usage});
  final CreditCard card;
  final CardUsage usage;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Abrir limites e datas do cartão final ${card.lastFour}',
    child: InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => showDetailSheet(
        context,
        title: '${card.name} • ${card.lastFour}',
        description: 'Configurações usadas para competência e projeções.',
        child: Column(
          children: [
            DetailValue(label: 'Banco', value: card.bank),
            DetailValue(label: 'Portador', value: card.holder),
            DetailValue(label: 'Fechamento', value: 'dia ${card.closingDay}'),
            DetailValue(label: 'Vencimento', value: 'dia ${card.dueDay}'),
            DetailValue(label: 'Limite', value: currency.format(card.limit)),
            DetailValue(
              label: 'Comprometido em faturas abertas',
              value: currency.format(usage.used),
            ),
            DetailValue(
              label: 'Disponível',
              value: currency.format(usage.available),
            ),
          ],
        ),
      ),
      child: Container(
        // Grows with Dynamic Type; the inner Spacers need a bounded height.
        height: 225 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF193C30), Color(0xFF285F49)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: context.palette.brand.withValues(alpha: .18),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: DefaultTextStyle(
          style: const TextStyle(color: Colors.white),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    card.bank.toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.contactless_rounded, color: Colors.white70),
                ],
              ),
              const Spacer(),
              Text(
                card.name,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '••••  ••••  ••••  ${card.lastFour}',
                style: const TextStyle(fontSize: 17, letterSpacing: 1.5),
              ),
              const Spacer(),
              if (usage.hasLimit) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: usage.ratio,
                    minHeight: 6,
                    backgroundColor: Colors.white24,
                    color: usage.isTight
                        ? context.palette.warning
                        : Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(
                    child: _CardDetail(
                      label: 'FECHA',
                      value: 'dia ${card.closingDay}',
                    ),
                  ),
                  Expanded(
                    child: _CardDetail(
                      label: 'VENCE',
                      value: 'dia ${card.dueDay}',
                    ),
                  ),
                  _CardDetail(
                    label: usage.hasLimit ? 'DISPONÍVEL' : 'LIMITE',
                    value: currency.format(
                      usage.hasLimit ? usage.available : card.limit,
                    ),
                    highlight: usage.isTight,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _CardDetail extends StatelessWidget {
  const _CardDetail({
    required this.label,
    required this.value,
    this.highlight = false,
  });
  final String label;
  final String value;
  final bool highlight;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 9,
          color: Colors.white60,
          letterSpacing: 1,
        ),
      ),
      const SizedBox(height: 3),
      Text(
        value,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
          color: highlight ? context.palette.warning : Colors.white,
        ),
      ),
    ],
  );
}

class _InvoicesList extends ConsumerWidget {
  const _InvoicesList({required this.snapshot, required this.period});
  final FinanceSnapshot snapshot;
  final FinancePeriod period;

  /// Only the invoices whose competence falls in the selected period. The page
  /// used to show the last twelve regardless, so navigating to another month
  /// changed every other screen and left this one alone.
  List<Invoice> get _visible => snapshot.invoices
      .where((item) => period.contains(item.referenceMonth))
      .toList();
  @override
  Widget build(BuildContext context, WidgetRef ref) => SectionCard(
    title: 'Faturas recentes',
    tooltip: 'Abrir todas as faturas e suas competências',
    onTap: () => showDetailSheet(
      context,
      title: 'Faturas recentes',
      description: 'Faturas importadas e calculadas pelo histórico.',
      child: Column(
        children: _visible
            .map(
              (item) => DetailValue(
                label: monthYear.format(item.referenceMonth),
                value: currency.format(item.total),
              ),
            )
            .toList(),
      ),
    ),
    child: Column(
      children: _visible.isEmpty
          ? [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'Nenhuma fatura com competência em ${period.label}.',
                  style: TextStyle(color: context.palette.inkMuted),
                ),
              ),
            ]
          : _visible.map((invoice) {
              final card = snapshot.cards
                  .where((item) => item.id == invoice.cardId)
                  .firstOrNull;
              final state = invoiceState(invoice);
              return Semantics(
                label:
                    'Ver detalhes da fatura de ${monthYear.format(invoice.referenceMonth)}',
                child: InkWell(
                  borderRadius: BorderRadius.circular(17),
                  onTap: () => showDetailSheet(
                    context,
                    title:
                        'Fatura de ${monthYear.format(invoice.referenceMonth)}',
                    description: card?.name ?? 'Cartão',
                    child: Column(
                      children: [
                        DetailValue(
                          label: 'Total pessoal',
                          value: currency.format(invoice.total),
                        ),
                        DetailValue(
                          label: 'Vencimento',
                          value: longDate.format(invoice.dueDate),
                        ),
                        DetailValue(label: 'Situação', value: state.label),
                        if (invoice.paidAt != null)
                          DetailValue(
                            label: 'Paga em',
                            value: longDate.format(invoice.paidAt!),
                          ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: state.isSettled
                              ? OutlinedButton.icon(
                                  onPressed: () => _setPaid(
                                    context,
                                    ref,
                                    invoice,
                                    paid: false,
                                  ),
                                  icon: const Icon(Icons.undo_rounded),
                                  label: const Text('Reabrir fatura'),
                                )
                              : FilledButton.icon(
                                  onPressed: () => _setPaid(
                                    context,
                                    ref,
                                    invoice,
                                    paid: true,
                                  ),
                                  icon: const Icon(
                                    Icons.check_circle_outline_rounded,
                                  ),
                                  label: const Text('Marcar como paga'),
                                ),
                        ),
                      ],
                    ),
                  ),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.palette.canvas,
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _stateColor(
                              context,
                              state,
                            ).withValues(alpha: .14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(switch (state) {
                            InvoiceState.paid => Icons.check_circle_rounded,
                            InvoiceState.overdue => Icons.error_outline_rounded,
                            InvoiceState.closed => Icons.lock_clock_rounded,
                            InvoiceState.open => Icons.schedule_rounded,
                          }, color: _stateColor(context, state)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                card?.name ?? 'Cartão',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                '${monthName.format(invoice.referenceMonth)} • vence dia ${invoice.dueDate.day}',
                                style: TextStyle(
                                  color: context.palette.inkSubtle,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              currency.format(invoice.total),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              state.label,
                              style: TextStyle(
                                color: _stateColor(context, state),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
    ),
  );
}

/// Paid is settled, overdue is the alarm, closed is awaiting payment and open
/// is still accumulating — four states the interface used to collapse into two.
Color _stateColor(BuildContext context, InvoiceState state) => switch (state) {
  InvoiceState.paid => context.palette.brand,
  InvoiceState.overdue => context.palette.danger,
  InvoiceState.closed => context.palette.onWarning,
  InvoiceState.open => context.palette.info,
};

/// Settling an invoice also frees the limit it was holding, because
/// [cardUsage] only counts invoices that are not paid — so the snapshot has to
/// reload for the card face to catch up.
Future<void> _setPaid(
  BuildContext context,
  WidgetRef ref,
  Invoice invoice, {
  required bool paid,
}) async {
  Navigator.of(context).pop();
  try {
    await ref
        .read(financeRepositoryProvider)
        .setInvoicePaid(invoice.id, paid: paid);
    await refreshFinanceSnapshot(ref);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            paid ? 'Fatura marcada como paga.' : 'Fatura reaberta.',
          ),
          backgroundColor: context.palette.brand,
        ),
      );
    }
  } on FinanceWriteException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: context.palette.danger,
        ),
      );
    }
  }
}
