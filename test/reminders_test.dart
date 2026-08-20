import 'package:financeiro_ai/features/ledger/domain/entities/models.dart';
import 'package:financeiro_ai/features/reminders/domain/reminders.dart';
import 'package:flutter_test/flutter_test.dart';

CreditCard _card({String id = 'card-1', String name = 'Nubank'}) => CreditCard(
  id: id,
  name: name,
  bank: 'Nu',
  lastFour: '1234',
  limit: 5000,
  closingDay: 20,
  dueDay: 27,
  holder: 'Você',
);

Invoice _invoice({
  String id = 'inv-1',
  String cardId = 'card-1',
  double total = 1200,
  required DateTime dueDate,
  String status = 'open',
  DateTime? paidAt,
}) => Invoice(
  id: id,
  cardId: cardId,
  referenceMonth: DateTime(dueDate.year, dueDate.month),
  total: total,
  dueDate: dueDate,
  status: status,
  paidAt: paidAt,
);

FinanceSnapshot _snapshot({
  List<Invoice> invoices = const [],
  List<CreditCard> cards = const [],
}) => FinanceSnapshot(
  transactions: const [],
  categories: const [],
  cards: cards,
  invoices: invoices,
  goals: const [],
  pendingReviews: 0,
);

void main() {
  // Well before the 27th, so a three-day warning still lies ahead.
  final now = DateTime(2026, 8, 18, 10);

  group('dueReminders', () {
    test('schedules the requested number of days before the due date', () {
      final reminders = dueReminders(
        _snapshot(
          cards: [_card()],
          invoices: [_invoice(dueDate: DateTime(2026, 8, 27))],
        ),
        daysBefore: 3,
        hour: 9,
        now: now,
      );

      expect(reminders, hasLength(1));
      expect(reminders.single.fireAt, DateTime(2026, 8, 24, 9));
      expect(reminders.single.daysBefore, 3);
      expect(reminders.single.cardName, 'Nubank');
    });

    test('skips an invoice that is already paid', () {
      final reminders = dueReminders(
        _snapshot(
          cards: [_card()],
          invoices: [
            _invoice(
              dueDate: DateTime(2026, 8, 27),
              status: 'paid',
              paidAt: DateTime(2026, 8, 15),
            ),
          ],
        ),
        daysBefore: 3,
        hour: 9,
        now: now,
      );

      expect(reminders, isEmpty);
    });

    test('skips a fire time that has already passed', () {
      // Three days before the 20th is the 17th — yesterday. Warning about it
      // now would fire immediately and say something already untrue.
      final reminders = dueReminders(
        _snapshot(
          cards: [_card()],
          invoices: [_invoice(dueDate: DateTime(2026, 8, 20))],
        ),
        daysBefore: 3,
        hour: 9,
        now: now,
      );

      expect(reminders, isEmpty);
    });

    test('skips an invoice with nothing on it', () {
      final reminders = dueReminders(
        _snapshot(
          cards: [_card()],
          invoices: [_invoice(dueDate: DateTime(2026, 8, 27), total: 0)],
        ),
        daysBefore: 3,
        hour: 9,
        now: now,
      );

      expect(reminders, isEmpty);
    });

    test('orders by when each reminder fires, not by invoice order', () {
      final reminders = dueReminders(
        _snapshot(
          cards: [
            _card(),
            _card(id: 'card-2', name: 'Itaú'),
          ],
          invoices: [
            _invoice(id: 'later', dueDate: DateTime(2026, 9, 10)),
            _invoice(
              id: 'sooner',
              cardId: 'card-2',
              dueDate: DateTime(2026, 8, 27),
            ),
          ],
        ),
        daysBefore: 3,
        hour: 9,
        now: now,
      );

      expect(reminders.map((e) => e.invoiceId), ['sooner', 'later']);
    });

    test('falls back to a generic name when the card is gone', () {
      final reminders = dueReminders(
        _snapshot(invoices: [_invoice(dueDate: DateTime(2026, 8, 27))]),
        daysBefore: 3,
        hour: 9,
        now: now,
      );

      expect(reminders.single.cardName, 'Cartão');
    });

    test('honours the chosen hour', () {
      final reminders = dueReminders(
        _snapshot(
          cards: [_card()],
          invoices: [_invoice(dueDate: DateTime(2026, 8, 27))],
        ),
        daysBefore: 5,
        hour: 20,
        now: now,
      );

      expect(reminders.single.fireAt, DateTime(2026, 8, 22, 20));
    });

    test('rolls into the previous month when the window crosses it', () {
      final reminders = dueReminders(
        _snapshot(
          cards: [_card()],
          invoices: [_invoice(dueDate: DateTime(2026, 9, 2))],
        ),
        daysBefore: 5,
        hour: 9,
        now: now,
      );

      expect(reminders.single.fireAt, DateTime(2026, 8, 28, 9));
    });
  });

  group('notificationId', () {
    test('is stable for the same invoice across rebuilds', () {
      final snapshot = _snapshot(
        cards: [_card()],
        invoices: [_invoice(dueDate: DateTime(2026, 8, 27))],
      );
      final first = dueReminders(snapshot, daysBefore: 3, hour: 9, now: now);
      final second = dueReminders(snapshot, daysBefore: 4, hour: 20, now: now);

      // Same id even though the schedule moved: syncing has to replace the
      // pending notification rather than stack a second one beside it.
      expect(first.single.notificationId, second.single.notificationId);
    });

    test('differs between invoices and is a positive 32-bit value', () {
      final reminders = dueReminders(
        _snapshot(
          cards: [
            _card(),
            _card(id: 'card-2', name: 'Itaú'),
          ],
          invoices: [
            _invoice(id: 'inv-a', dueDate: DateTime(2026, 8, 27)),
            _invoice(
              id: 'inv-b',
              cardId: 'card-2',
              dueDate: DateTime(2026, 8, 28),
            ),
          ],
        ),
        daysBefore: 3,
        hour: 9,
        now: now,
      );

      final ids = reminders.map((e) => e.notificationId).toList();
      expect(ids.toSet(), hasLength(2));
      expect(ids.every((id) => id >= 0), isTrue);
    });
  });

  group('copy', () {
    test('says "dia" in the singular', () {
      final reminder = dueReminders(
        _snapshot(
          cards: [_card()],
          invoices: [_invoice(dueDate: DateTime(2026, 8, 27))],
        ),
        daysBefore: 1,
        hour: 9,
        now: now,
      ).single;

      expect(reminderTitle(reminder), 'Fatura Nubank vence em 1 dia');
    });

    test('carries the amount and the date in the body', () {
      final reminder = dueReminders(
        _snapshot(
          cards: [_card()],
          invoices: [_invoice(dueDate: DateTime(2026, 9, 5), total: 1234.5)],
        ),
        daysBefore: 3,
        hour: 9,
        now: now,
      ).single;

      expect(
        reminderBody(reminder, (v) => 'R\$ ${v.toStringAsFixed(2)}'),
        'R\$ 1234.50 com vencimento em 05/09.',
      );
    });
  });
}
