import 'package:clock/clock.dart';
import 'package:financeiro_ai/features/ledger/domain/entities/models.dart';

enum InvoiceState { open, closed, paid, overdue }

/// The state to show the person, which is not always the stored one.
///
/// Nothing in the system moves an invoice to `overdue`: the column exists but
/// no job writes it, so an unpaid invoice sits at `open` or `closed` forever
/// past its due date. Deriving it from the due date is what makes the screen
/// tell the truth.
InvoiceState invoiceState(Invoice invoice, {DateTime? now}) {
  if (invoice.status == 'paid') return InvoiceState.paid;
  final today = now ?? clock.now();
  final due = DateTime(
    invoice.dueDate.year,
    invoice.dueDate.month,
    invoice.dueDate.day,
  );
  if (DateTime(today.year, today.month, today.day).isAfter(due)) {
    return InvoiceState.overdue;
  }
  return invoice.status == 'closed' ? InvoiceState.closed : InvoiceState.open;
}

extension InvoiceStateLabel on InvoiceState {
  String get label => switch (this) {
    InvoiceState.open => 'Aberta',
    InvoiceState.closed => 'Fechada',
    InvoiceState.paid => 'Paga',
    InvoiceState.overdue => 'Vencida',
  };

  /// Whether the state needs the person to do something.
  bool get needsAttention =>
      this == InvoiceState.overdue || this == InvoiceState.closed;

  bool get isSettled => this == InvoiceState.paid;
}
