import 'package:financeiro_ai/domain/invoice_status.dart';
import 'package:financeiro_ai/domain/load_failure.dart';
import 'package:financeiro_ai/data/demo_finance_repository.dart';
import 'package:financeiro_ai/domain/comparison.dart';
import 'package:financeiro_ai/domain/models.dart';
import 'package:financeiro_ai/domain/transaction_draft.dart';
import 'package:flutter_test/flutter_test.dart';

Invoice invoice({required String status, required DateTime dueDate}) => Invoice(
  id: '1',
  cardId: 'c1',
  referenceMonth: DateTime(2026, 8),
  total: 100,
  dueDate: dueDate,
  status: status,
);

void main() {
  group('invoiceState', () {
    final today = DateTime(2026, 8, 18);

    test('paid wins even when the due date has passed', () {
      expect(
        invoiceState(
          invoice(status: 'paid', dueDate: DateTime(2026, 8, 1)),
          now: today,
        ),
        InvoiceState.paid,
      );
    });

    test('an unpaid invoice past its due date reads as overdue', () {
      // Nothing writes `overdue`, so an unpaid invoice sits at open or closed
      // forever; deriving it is what makes the screen tell the truth.
      expect(
        invoiceState(
          invoice(status: 'closed', dueDate: DateTime(2026, 8, 17)),
          now: today,
        ),
        InvoiceState.overdue,
      );
      expect(
        invoiceState(
          invoice(status: 'open', dueDate: DateTime(2026, 7, 9)),
          now: today,
        ),
        InvoiceState.overdue,
      );
    });

    test('the due date itself is not yet overdue', () {
      expect(
        invoiceState(
          invoice(status: 'closed', dueDate: today),
          now: today,
        ),
        InvoiceState.closed,
      );
    });

    test('closed and open stay distinct before the due date', () {
      expect(
        invoiceState(
          invoice(status: 'closed', dueDate: DateTime(2026, 9, 9)),
          now: today,
        ),
        InvoiceState.closed,
      );
      expect(
        invoiceState(
          invoice(status: 'open', dueDate: DateTime(2026, 9, 9)),
          now: today,
        ),
        InvoiceState.open,
      );
    });

    test('every state has a distinct Portuguese label', () {
      final labels = InvoiceState.values.map((item) => item.label).toList();
      expect(labels, ['Aberta', 'Fechada', 'Paga', 'Vencida']);
      expect(labels.toSet(), hasLength(4));
    });

    test('only paid counts as settled', () {
      expect(InvoiceState.paid.isSettled, isTrue);
      expect(InvoiceState.overdue.isSettled, isFalse);
      expect(InvoiceState.overdue.needsAttention, isTrue);
      expect(InvoiceState.open.needsAttention, isFalse);
    });
  });

  group('LoadFailure', () {
    test('recognises a dropped connection', () {
      final failure = LoadFailure.from(
        Exception('SocketException: Failed host lookup'),
      );
      expect(failure.message, 'Sem conexão com o servidor');
      expect(failure.canRetry, isTrue);
    });

    test('recognises a timeout', () {
      expect(
        LoadFailure.from(Exception('Connection timed out')).message,
        'O servidor demorou para responder',
      );
    });

    test('an expired session is not offered a retry', () {
      final failure = LoadFailure.from(Exception('JWT expired'));
      expect(failure.message, 'Sua sessão expirou');
      expect(failure.canRetry, isFalse);
    });

    test('recognises a policy rejection', () {
      expect(
        LoadFailure.from(
          Exception('new row violates row-level security policy'),
        ).message,
        'Sem permissão para ler estes dados',
      );
    });

    test('an unknown error still gets a readable message', () {
      final failure = LoadFailure.from(Exception('weird backend explosion'));
      expect(failure.message, 'Não foi possível carregar seus dados');
      expect(failure.canRetry, isTrue);
    });

    test('the raw text is preserved for debugging', () {
      final failure = LoadFailure.from(Exception('PostgrestException(42P01)'));
      expect(failure.detail, contains('42P01'));
    });
  });

  group('Marcar fatura como paga', () {
    test('settling stamps the date and switches the status', () async {
      final repository = DemoFinanceRepository();
      await repository.setInvoicePaid('2', paid: true);
      final invoice = (await repository.loadSnapshot()).invoices.firstWhere(
        (item) => item.id == '2',
      );
      expect(invoice.status, 'paid');
      expect(invoice.paidAt, isNotNull);
      expect(invoiceState(invoice), InvoiceState.paid);
    });

    test('a paid invoice stops reading as overdue', () async {
      final repository = DemoFinanceRepository();
      final before = (await repository.loadSnapshot()).invoices.firstWhere(
        (item) => item.id == '2',
      );
      // The demo invoice 2 is due on the 10th, so it is late for most of a month.
      expect(
        invoiceState(
          before,
          now: DateTime(before.dueDate.year, before.dueDate.month, 28),
        ),
        InvoiceState.overdue,
      );
      await repository.setInvoicePaid('2', paid: true);
      final after = (await repository.loadSnapshot()).invoices.firstWhere(
        (item) => item.id == '2',
      );
      expect(
        invoiceState(
          after,
          now: DateTime(after.dueDate.year, after.dueDate.month, 28),
        ),
        InvoiceState.paid,
      );
    });

    test('paying releases the billed part but not the scheduled one', () async {
      final repository = DemoFinanceRepository();
      final card = (await repository.loadSnapshot()).cards.firstWhere(
        (item) => item.id == '2',
      );
      final before = cardUsage(await repository.loadSnapshot(), card);
      expect(before.billed, greaterThan(0));

      await repository.setInvoicePaid('2', paid: true);
      final after = cardUsage(await repository.loadSnapshot(), card);
      expect(after.billed, 0, reason: 'the invoice no longer holds limit');
      // The demo ledger has a 2-of-4 instalment on this card; those two
      // remaining charges are committed at the issuer whether or not the
      // current invoice was paid.
      expect(after.scheduled, greaterThan(0));
      expect(after.used, after.scheduled);
      expect(after.available, card.limit - after.scheduled);
    });

    test('reopening clears the date and restores the commitment', () async {
      final repository = DemoFinanceRepository();
      await repository.setInvoicePaid('2', paid: true);
      await repository.setInvoicePaid('2', paid: false);
      final snapshot = await repository.loadSnapshot();
      final invoice = snapshot.invoices.firstWhere((item) => item.id == '2');
      expect(invoice.status, 'closed');
      expect(invoice.paidAt, isNull);
      final card = snapshot.cards.firstWhere((item) => item.id == '2');
      expect(cardUsage(snapshot, card).used, greaterThan(0));
    });

    test('an unknown invoice is refused rather than ignored', () async {
      await expectLater(
        DemoFinanceRepository().setInvoicePaid('nope', paid: true),
        throwsA(isA<FinanceWriteException>()),
      );
    });

    test('fromJson reads paid_at', () {
      final invoice = Invoice.fromJson({
        'id': '1',
        'card_id': 'c1',
        'reference_month': '2026-08-01',
        'total': 100,
        'due_date': '2026-08-10',
        'status': 'paid',
        'paid_at': '2026-08-09T12:00:00Z',
      });
      expect(invoice.paidAt, isNotNull);
      expect(invoiceState(invoice), InvoiceState.paid);
    });
  });
}
