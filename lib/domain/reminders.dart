import 'package:financeiro_ai/domain/invoice_status.dart';
import 'package:financeiro_ai/domain/models.dart';

/// A notification to schedule for an invoice about to come due.
class DueReminder {
  const DueReminder({
    required this.invoiceId,
    required this.cardName,
    required this.total,
    required this.dueDate,
    required this.fireAt,
    required this.daysBefore,
  });

  final String invoiceId;
  final String cardName;
  final double total;
  final DateTime dueDate;
  final DateTime fireAt;

  /// How many days ahead of the due date this fires.
  ///
  /// Carried rather than derived from [dueDate] and [fireAt]: those differ by
  /// whole days *plus* the chosen hour, so subtracting them truncates — three
  /// days before at 09:00 measures as 2 days and 15 hours, and the copy would
  /// promise a day that has already gone.
  final int daysBefore;

  /// Stable across reschedules, so syncing replaces a reminder instead of
  /// stacking a second copy of it.
  int get notificationId => invoiceId.hashCode & 0x7fffffff;
}

/// Which reminders should exist right now.
///
/// Deliberately recomputed from scratch and applied as a replacement rather
/// than appended: an invoice that gets paid, reopened or re-dated has to lose
/// or move its reminder, and the only way to be sure is to derive the whole
/// set every time.
List<DueReminder> dueReminders(
  FinanceSnapshot snapshot, {
  required int daysBefore,
  required int hour,
  DateTime? now,
}) {
  final moment = now ?? DateTime.now();
  final reminders = <DueReminder>[];

  for (final invoice in snapshot.invoices) {
    // A settled invoice has nothing to warn about, and an overdue one has
    // nothing left to warn about either — the moment to act already passed.
    if (invoiceState(invoice, now: moment) == InvoiceState.paid) continue;
    if (invoice.total <= 0) continue;

    final fireAt = DateTime(
      invoice.dueDate.year,
      invoice.dueDate.month,
      invoice.dueDate.day - daysBefore,
      hour,
    );
    if (!fireAt.isAfter(moment)) continue;

    final card = snapshot.cards
        .where((item) => item.id == invoice.cardId)
        .firstOrNull;
    reminders.add(
      DueReminder(
        invoiceId: invoice.id,
        cardName: card?.name ?? 'Cartão',
        total: invoice.total,
        dueDate: invoice.dueDate,
        fireAt: fireAt,
        daysBefore: daysBefore,
      ),
    );
  }

  reminders.sort((a, b) => a.fireAt.compareTo(b.fireAt));
  return reminders;
}

String reminderTitle(DueReminder reminder) =>
    'Fatura ${reminder.cardName} vence em ${reminder.daysBefore} '
    '${reminder.daysBefore == 1 ? 'dia' : 'dias'}';

String reminderBody(DueReminder reminder, String Function(double) money) =>
    '${money(reminder.total)} com vencimento em '
    '${reminder.dueDate.day.toString().padLeft(2, '0')}/'
    '${reminder.dueDate.month.toString().padLeft(2, '0')}.';
