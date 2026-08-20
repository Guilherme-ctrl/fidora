/// The vocabulary of failure, in three families.
///
/// Before this the project had four incompatible models: `FinanceWriteException`
/// carrying a Portuguese sentence written by the repository, `LoadFailure`
/// classifying by substring of whatever `toString()` produced, the import
/// exceptions with their own message field, and `AuthException` from
/// `supabase_flutter` arriving intact at a widget.
///
/// The cost was not tidiness. A screen could not tell "this purchase is already
/// in your history" from "your session expired" — both arrived as the same
/// class with different text — so neither could get the response it deserves:
/// the first should offer to open the existing row, the second should send the
/// person to sign in. And no sentence could ever be translated, because the
/// sentence was written three layers below the screen.
///
/// The split follows the three the reference architecture asks for:
///
/// * [BusinessFailure] — a rule of the product said no. Expected, and the
///   person can usually act on it.
/// * [TechnicalFailure] — the infrastructure could not complete the work.
///   Nothing is wrong with what was asked.
/// * [UnexpectedFailure] — nothing recognised it. Carries the cause and the
///   stack so it can be read later, which is what the eight `catch (_)` used to
///   throw away.
///
/// Failures implement [Exception] and are thrown, rather than returned in a
/// `Result`. That keeps the control flow the codebase already uses everywhere,
/// and `on Failure catch (failure)` gives the same exhaustive switch a sealed
/// return type would.
library;

sealed class Failure implements Exception {
  const Failure();
}

// --------------------------------------------------------------------------
// Business
// --------------------------------------------------------------------------

/// A rule of the product refused the operation.
sealed class BusinessFailure extends Failure {
  const BusinessFailure();
}

/// The ledger already holds this purchase.
///
/// Raised by the `transactions_user_id_dedup_key_key` constraint, which is the
/// database half of the promise that a captured purchase is never counted
/// twice.
final class DuplicateTransaction extends BusinessFailure {
  const DuplicateTransaction();
}

/// An amount that is zero or negative reached the write.
final class InvalidAmount extends BusinessFailure {
  const InvalidAmount();
}

/// Two cards cannot share a final four.
final class DuplicateCard extends BusinessFailure {
  const DuplicateCard();
}

final class InvalidCardLastFour extends BusinessFailure {
  const InvalidCardLastFour();
}

/// Closing and due days run from 1 to 31.
final class InvalidCardDay extends BusinessFailure {
  const InvalidCardDay();
}

final class DuplicateCategory extends BusinessFailure {
  const DuplicateCategory();
}

final class DuplicateAccount extends BusinessFailure {
  const DuplicateAccount();
}

final class DuplicateHolder extends BusinessFailure {
  const DuplicateHolder();
}

/// Two rules cannot claim the same merchant fragment.
final class DuplicateMerchantRule extends BusinessFailure {
  const DuplicateMerchantRule();
}

/// The row a write depends on is gone — a card deactivated in another session,
/// an invoice removed, a token already revoked.
final class RecordNotFound extends BusinessFailure {
  const RecordNotFound(this.what);

  /// Which record, so the copy can name it.
  final RecordKind what;
}

enum RecordKind { card, category, invoice, token, receipt, transaction }

/// A draft failed its own validation before anything was sent.
///
/// The message originates in the domain rule, not in the database, so it is
/// carried rather than re-derived: `TransactionDraft.validate()` is the
/// authority on what "a instalment cannot exceed its total" means.
final class ValidationFailure extends BusinessFailure {
  const ValidationFailure(this.message);
  final String message;
}

// --------------------------------------------------------------------------
// Technical
// --------------------------------------------------------------------------

/// The infrastructure could not complete the work.
sealed class TechnicalFailure extends Failure {
  const TechnicalFailure();
}

/// The session is gone or the token expired. The person must sign in again.
final class SessionExpired extends TechnicalFailure {
  const SessionExpired();
}

/// Row-level security refused the row. Distinct from [SessionExpired]: the
/// session is valid, it just does not own this data.
final class PermissionDenied extends TechnicalFailure {
  const PermissionDenied();
}

/// No route to the server.
final class NetworkUnavailable extends TechnicalFailure {
  const NetworkUnavailable();
}

/// The server took too long. Checked before [NetworkUnavailable] because
/// "connection timed out" matches both and the timeout is the more specific
/// diagnosis.
final class RequestTimeout extends TechnicalFailure {
  const RequestTimeout();
}

/// The receipt is past the bucket's limit.
final class ReceiptTooLarge extends TechnicalFailure {
  const ReceiptTooLarge();
}

/// Storage refused the object for a reason that is not size.
final class StorageUnavailable extends TechnicalFailure {
  const StorageUnavailable();
}

/// Credentials were rejected, or the account cannot be created.
///
/// Carries the provider's own text: authentication failures are numerous,
/// change with provider configuration, and the provider phrases them for the
/// end user. Typing every one of them would be inventing a taxonomy that only
/// this class would ever read.
final class AuthenticationFailure extends TechnicalFailure {
  const AuthenticationFailure(this.reason);
  final String reason;
}

// --------------------------------------------------------------------------
// Unexpected
// --------------------------------------------------------------------------

/// Nothing recognised this.
///
/// [cause] and [stack] are kept because the eight `catch (_)` this class
/// replaces discarded exactly this, and the project has no crash reporting to
/// recover it from.
final class UnexpectedFailure extends Failure {
  const UnexpectedFailure(this.cause, this.stack);
  final Object cause;
  final StackTrace stack;

  @override
  String toString() => 'UnexpectedFailure: $cause';
}

// --------------------------------------------------------------------------
// Transport-level classification
// --------------------------------------------------------------------------

/// Anything at all, as a [Failure].
///
/// A repository maps its own exceptions at its boundary, so above `lib/data`
/// every failure already arrives typed and this passes it straight through.
/// The fallback exists because the framework's error slot carries `Object`,
/// not `Failure`, and a widget reading it cannot prove what survived.
Failure asFailure(Object error, StackTrace stack) =>
    error is Failure ? error : classifyTransport(error, stack);

/// Classifies the failures any transport can produce, regardless of backend.
///
/// Backend-specific mapping does not belong here — `PostgrestException` is
/// known to `lib/data`, and this file must stay ignorant of which database is
/// behind the repository. What is shared is the shape of a dead network, and
/// that is all this reads.
Failure classifyTransport(Object error, StackTrace stack) {
  final text = '$error'.toLowerCase();
  if (text.contains('timeout') || text.contains('timed out')) {
    return const RequestTimeout();
  }
  if (text.contains('socketexception') ||
      text.contains('failed host lookup') ||
      text.contains('clientexception') ||
      text.contains('connection') ||
      text.contains('network')) {
    return const NetworkUnavailable();
  }
  if (text.contains('jwt') ||
      text.contains('not authenticated') ||
      text.contains('invalid_token')) {
    return const SessionExpired();
  }
  return UnexpectedFailure(error, stack);
}
