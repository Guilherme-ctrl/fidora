import 'package:financeiro_ai/core/breakpoints.dart';
import 'package:financeiro_ai/core/theme.dart';
import 'package:financeiro_ai/core/tokens.dart';
import 'package:financeiro_ai/core/typography.dart';
import 'package:financeiro_ai/domain/analytics.dart';
import 'package:financeiro_ai/domain/comparison.dart';
import 'package:financeiro_ai/domain/invoice_status.dart';
import 'package:financeiro_ai/domain/models.dart';
import 'package:financeiro_ai/presentation/widgets/card_form_sheet.dart';
import 'package:financeiro_ai/presentation/widgets/invoice_forecast_card.dart';
import 'package:financeiro_ai/presentation/widgets/common.dart';
import 'package:financeiro_ai/presentation/widgets/ledger.dart';
import 'package:financeiro_ai/core/errors/failure.dart';
import 'package:financeiro_ai/presentation/failure_copy.dart';
import 'package:financeiro_ai/presentation/cubits/finance_cubit.dart';
import 'package:financeiro_ai/domain/repositories/repositories.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
        Breakpoint.of(context).gutter,
        Space.xl,
        Breakpoint.of(context).gutter,
        Space.xxxl,
      ),
      children: [
        PageHeading(
          title: 'Cartões e faturas',
          subtitle: 'Quanto ainda dá para usar, quando fecha e quando vence.',
          action: width > 560
              ? FilledButton.icon(
                  onPressed: () =>
                      editCard(context, holders: snapshot.holders),
                  icon: const Icon(Icons.add_card),
                  label: const Text('Adicionar cartão'),
                )
              : null,
        ),
        const SizedBox(height: 22),
        // Above the cards on purpose: "quanto vai dar" is the question this
        // page is opened to answer, and it is the only one here about the
        // future. It removes itself when there is nothing to forecast.
        InvoiceForecastCard(snapshot: snapshot),
        const SizedBox(height: 14),
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
                        onEdit: () => editCard(
                          context,
                          holders: snapshot.holders,
                          existing: card,
                        ),
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
  const _CreditCardView({
    required this.card,
    required this.usage,
    required this.onEdit,
  });
  final CreditCard card;
  final CardUsage usage;
  final VoidCallback onEdit;
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
              value: currency.format(usage.billed),
            ),
            if (usage.scheduled > 0)
              DetailValue(
                label: 'Parcelas ainda não faturadas',
                value: currency.format(usage.scheduled),
              ),
            DetailValue(
              label: 'Disponível',
              value: currency.format(usage.available),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  onEdit();
                },
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Editar cartão'),
              ),
            ),
          ],
        ),
      ),
      child: Container(
        // A minimum, not a height. The old value scaled with Dynamic Type but
        // capped at 1.6x, and once real fonts were bundled the content ran 141px
        // past it at 2x — the test font's boxes had been narrower than the
        // letters they stood in for. The card now takes the height its content
        // needs and the `Spacer`s became fixed gaps, which is what allowed the
        // bound to go away.
        constraints: BoxConstraints(
          minHeight:
              225 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6),
        ),
        padding: const EdgeInsets.all(Space.xl),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: context.palette.cardGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(Radii.md),
          boxShadow: [
            BoxShadow(
              color: context.palette.accent.withValues(alpha: .18),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: DefaultTextStyle(
          // A face do cartão era a única superfície do app com a fonte do
          // sistema: um `TextStyle` cru não herda a família do tema, e a
          // diferença só apareceu quando as fontes passaram a ser desenhadas
          // nas imagens de referência.
          style: context.type.bodyMd.copyWith(color: context.palette.onCard),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Spaced capitals grow fast: at 1.3x a long bank name pushed
                  // the contactless glyph 13px past the card face.
                  Expanded(
                    child: Text(
                      card.bank.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.contactless_rounded, color: Colors.white70),
                ],
              ),
              const SizedBox(height: Space.lg),
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
              const SizedBox(height: Space.lg),
              if (usage.hasLimit) ...[
                RuleBar(
                  value: usage.ratio,
                  height: 4,
                  trackColor: Colors.white24,
                  color: usage.isTight ? context.palette.pending : Colors.white,
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
          color: highlight ? context.palette.pending : Colors.white,
        ),
      ),
    ],
  );
}

class _InvoicesList extends StatelessWidget {
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
  Widget build(BuildContext context) => RuledSection(
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
                                    invoice,
                                    paid: false,
                                  ),
                                  icon: const Icon(Icons.undo_rounded),
                                  label: const Text('Reabrir fatura'),
                                )
                              : FilledButton.icon(
                                  onPressed: () => _setPaid(
                                    context,
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
  InvoiceState.paid => context.palette.income,
  InvoiceState.overdue => context.palette.negative,
  InvoiceState.closed => context.palette.pending,
  InvoiceState.open => context.palette.accent,
};

/// Settling an invoice also frees the limit it was holding, because
/// [cardUsage] only counts invoices that are not paid — so the snapshot has to
/// reload for the card face to catch up.
Future<void> _setPaid(
  BuildContext context,
  Invoice invoice, {
  required bool paid,
}) async {
  Navigator.of(context).pop();
  try {
    final invoices = context.read<InvoiceRepository>();
    final finance = context.read<FinanceCubit>();
    await invoices.setInvoicePaid(invoice.id, paid: paid);
    await finance.reloadLedger();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            paid ? 'Fatura marcada como paga.' : 'Fatura reaberta.',
          ),
          backgroundColor: context.palette.accent,
        ),
      );
    }
  } on Failure catch (failure) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(FailureCopy.of(failure).short),
          backgroundColor: context.palette.negative,
        ),
      );
    }
  }
}
