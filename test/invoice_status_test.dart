import 'package:financeiro_ai/domain/invoice_status.dart';
import 'package:financeiro_ai/domain/load_failure.dart';
import 'package:financeiro_ai/domain/models.dart';
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
}
