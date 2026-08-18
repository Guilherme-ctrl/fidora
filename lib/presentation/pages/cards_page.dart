import 'package:financeiro_ai/core/theme.dart';
import 'package:financeiro_ai/domain/models.dart';
import 'package:financeiro_ai/presentation/widgets/common.dart';
import 'package:flutter/material.dart';

class CardsPage extends StatelessWidget {
  const CardsPage({super.key, required this.snapshot});
  final FinanceSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        width < 600 ? 18 : 32,
        24,
        width < 600 ? 18 : 32,
        36,
      ),
      children: [
        PageHeading(
          title: 'Cartões e faturas',
          subtitle: 'Fechamento, vencimento, parcelas e limites sem surpresas.',
          action: width > 560
              ? Tooltip(
                  message: 'Cadastrar um novo cartão de crédito',
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
                      child: _CreditCardView(card: card),
                    ),
                  )
                  .toList(),
            );
            final invoices = _InvoicesList(snapshot: snapshot);
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
  const _CreditCardView({required this.card});
  final CreditCard card;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Abrir limites e datas do cartão final ${card.lastFour}',
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
          ],
        ),
      ),
      child: Container(
        height: 225,
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
              color: moss.withValues(alpha: .18),
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
                    label: 'LIMITE',
                    value: currency.format(card.limit),
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
  const _CardDetail({required this.label, required this.value});
  final String label;
  final String value;
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
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
      ),
    ],
  );
}

class _InvoicesList extends StatelessWidget {
  const _InvoicesList({required this.snapshot});
  final FinanceSnapshot snapshot;
  @override
  Widget build(BuildContext context) => SectionCard(
    title: 'Faturas recentes',
    tooltip: 'Abrir todas as faturas e suas competências',
    onTap: () => showDetailSheet(
      context,
      title: 'Faturas recentes',
      description: 'Faturas importadas e calculadas pelo histórico.',
      child: Column(
        children: snapshot.invoices
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
      children: snapshot.invoices.map((invoice) {
        final card = snapshot.cards
            .where((item) => item.id == invoice.cardId)
            .firstOrNull;
        final open = invoice.status == 'open';
        return Tooltip(
          message:
              'Ver detalhes da fatura de ${monthYear.format(invoice.referenceMonth)}',
          child: InkWell(
            borderRadius: BorderRadius.circular(17),
            onTap: () => showDetailSheet(
              context,
              title: 'Fatura de ${monthYear.format(invoice.referenceMonth)}',
              description: card?.name ?? 'Cartão',
              child: Column(
                children: [
                  DetailValue(
                    label: 'Total pessoal',
                    value: currency.format(invoice.total),
                  ),
                  DetailValue(
                    label: 'Vencimento',
                    value:
                        '${invoice.dueDate.day}/${invoice.dueDate.month}/${invoice.dueDate.year}',
                  ),
                  DetailValue(label: 'Status', value: invoice.status),
                ],
              ),
            ),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: canvas,
                borderRadius: BorderRadius.circular(17),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: open ? coral.withValues(alpha: .12) : mint,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      open
                          ? Icons.schedule_rounded
                          : Icons.check_circle_rounded,
                      color: open ? coral : moss,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          card?.name ?? 'Cartão',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          '${monthName.format(invoice.referenceMonth)} • vence dia ${invoice.dueDate.day}',
                          style: TextStyle(
                            color: ink.withValues(alpha: .55),
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
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        open ? 'Aberta' : 'Fechada',
                        style: TextStyle(
                          color: open ? coral : moss,
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
