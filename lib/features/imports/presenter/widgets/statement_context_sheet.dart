import 'package:financeiro_ai/core/theme/theme.dart';
import 'package:financeiro_ai/features/ledger/domain/finance_rules.dart';
import 'package:financeiro_ai/features/ledger/domain/entities/models.dart';
import 'package:financeiro_ai/features/imports/domain/statement_import.dart';
import 'package:financeiro_ai/features/imports/domain/statement_sheet.dart';
import 'package:financeiro_ai/core/design_system/common.dart';
import 'package:financeiro_ai/core/design_system/ledger.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final _monthLabel = DateFormat("MMMM 'de' y", 'pt_BR');

/// Asks for the two things a bank's spreadsheet does not carry: which card it
/// belongs to, and which invoice month.
///
/// The month is inferred from the rows and offered for confirmation rather than
/// typed. Filing a statement under the wrong month is invisible at import and
/// then wrong forever.
Future<StatementContext?> askStatementContext(
  BuildContext context, {
  required List<CreditCard> cards,
  required StatementParse parse,
  required String fileName,
}) => showResponsiveSurface<StatementContext>(
  context,
  builder: (_) =>
      _StatementContextSheet(cards: cards, parse: parse, fileName: fileName),
);

/// The invoice month most of the rows fall into, by the card's closing day.
///
/// A statement always straddles two calendar months, so "the month of the first
/// row" is wrong about half the time. The most common competence is right
/// unless the file mixes two invoices, which is not a thing banks export.
DateTime inferCompetence(StatementParse parse, CreditCard card) {
  final counts = <DateTime, int>{};
  for (final row in parse.rows) {
    final competence = invoiceCompetence(row.date, card.closingDay);
    counts[competence] = (counts[competence] ?? 0) + 1;
  }
  final entries = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return entries.first.key;
}

class _StatementContextSheet extends StatefulWidget {
  const _StatementContextSheet({
    required this.cards,
    required this.parse,
    required this.fileName,
  });

  final List<CreditCard> cards;
  final StatementParse parse;
  final String fileName;

  @override
  State<_StatementContextSheet> createState() => _StatementContextSheetState();
}

class _StatementContextSheetState extends State<_StatementContextSheet> {
  late CreditCard? _card = widget.cards.firstOrNull;
  DateTime? _competence;

  DateTime get _month => _competence ?? inferCompetence(widget.parse, _card!);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final card = _card;
    final purchases = widget.parse.rows.where((row) => !row.isPayment).length;
    final payments = widget.parse.rows.length - purchases;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Importar planilha',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              widget.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: palette.inkMuted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            _Summary(
              purchases: purchases,
              payments: payments,
              total: widget.parse.total,
              skipped: widget.parse.skipped,
            ),
            const SizedBox(height: 20),
            if (widget.cards.isEmpty)
              Text(
                'Cadastre um cartão antes de importar: a planilha não diz a '
                'qual cartão ela pertence.',
                style: TextStyle(color: palette.negative, height: 1.45),
              )
            else ...[
              DropdownButtonFormField<String>(
                initialValue: card?.id,
                decoration: const InputDecoration(labelText: 'Cartão'),
                items: widget.cards
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.id,
                        child: Text('${item.name} • ${item.lastFour}'),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() {
                  _card = widget.cards.firstWhere((item) => item.id == value);
                  // The inference depends on the card's closing day, so a
                  // different card means a different month.
                  _competence = null;
                }),
              ),
              const SizedBox(height: 14),
              _MonthField(
                month: _month,
                onChanged: (value) => setState(() => _competence = value),
              ),
              const SizedBox(height: 6),
              Text(
                'Deduzido do dia de fechamento do cartão e das datas da '
                'planilha. Confira: uma fatura arquivada no mês errado fica '
                'errada para sempre.',
                style: TextStyle(
                  color: palette.inkSubtle,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 22),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: card == null
                      ? null
                      : () => Navigator.of(context).pop(
                          StatementContext(
                            bank: card.bank,
                            cardLastFour: card.lastFour,
                            referenceMonth: _month,
                            dueDate: DateTime(
                              _month.year,
                              _month.month,
                              card.dueDay,
                            ),
                            fileName: widget.fileName,
                          ),
                        ),
                  child: const Text('Continuar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthField extends StatelessWidget {
  const _MonthField({required this.month, required this.onChanged});
  final DateTime month;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) => InputDecorator(
    decoration: const InputDecoration(labelText: 'Mês da fatura'),
    child: Row(
      children: [
        Expanded(child: Text(_monthLabel.format(month))),
        IconButton(
          tooltip: 'Mês anterior',
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: () => onChanged(DateTime(month.year, month.month - 1)),
        ),
        IconButton(
          tooltip: 'Próximo mês',
          icon: const Icon(Icons.chevron_right_rounded),
          onPressed: () => onChanged(DateTime(month.year, month.month + 1)),
        ),
      ],
    ),
  );
}

/// What the parser made of the file, before anything is written.
class _Summary extends StatelessWidget {
  const _Summary({
    required this.purchases,
    required this.payments,
    required this.total,
    required this.skipped,
  });

  final int purchases;
  final int payments;
  final double total;
  final List<String> skipped;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.canvas,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$purchases ${purchases == 1 ? 'compra' : 'compras'}'
            '${payments > 0 ? ' · $payments ${payments == 1 ? 'pagamento' : 'pagamentos'}' : ''}'
            ' · ${currency.format(total)}',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
          if (skipped.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '${skipped.length} ${skipped.length == 1 ? 'linha não foi lida' : 'linhas não foram lidas'}:',
              style: TextStyle(
                color: palette.pending,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            // Listed rather than counted: a skipped line is a purchase that
            // will be missing from the ledger, and a number alone does not let
            // anyone go and check which one.
            ...skipped
                .take(5)
                .map(
                  (line) => Text(
                    '• $line',
                    style: TextStyle(
                      color: palette.inkMuted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
            if (skipped.length > 5)
              Text(
                '• e mais ${skipped.length - 5}',
                style: TextStyle(color: palette.inkMuted, fontSize: 12),
              ),
          ],
        ],
      ),
    );
  }
}
