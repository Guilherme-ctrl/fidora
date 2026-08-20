import 'package:financeiro_ai/core/errors/failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Translates what Supabase throws into the vocabulary the rest of the app
/// speaks.
///
/// This is the only file in the project that is allowed to know both
/// `PostgrestException` and [Failure]. Above it nothing imports
/// `supabase_flutter`; below it nothing writes a sentence for a person.
///
/// The constraint names are the contract. `transactions_user_id_dedup_key_key`
/// is not an implementation detail that leaked — it is the database half of
/// "no silent duplicate charges", and reading it here is how that promise
/// reaches the screen.
extension PostgrestFailure on PostgrestException {
  Failure toFailure(StackTrace stack) {
    final text = '$code $message';

    if (text.contains('transactions_user_id_dedup_key_key')) {
      return const DuplicateTransaction();
    }
    if (text.contains('amount_check')) return const InvalidAmount();
    if (text.contains('cards_user_id_last_four_key')) {
      return const DuplicateCard();
    }
    if (text.contains('last_four_check')) return const InvalidCardLastFour();
    if (text.contains('closing_day_check') || text.contains('due_day_check')) {
      return const InvalidCardDay();
    }
    if (text.contains('categories_user_id_name_key')) {
      return const DuplicateCategory();
    }
    if (text.contains('accounts_user_id_name_key')) {
      return const DuplicateAccount();
    }
    if (text.contains('holders_user_id_name_key')) {
      return const DuplicateHolder();
    }
    if (text.contains('merchant_rules_user_id_pattern_key')) {
      return const DuplicateMerchantRule();
    }
    // Row-level security refusing a row is not an expired session: the token is
    // valid, it simply does not own this data. The two were the same message
    // before, which is why a genuine ownership bug looked like a login problem.
    if (code == '42501' || text.contains('row-level security')) {
      return const PermissionDenied();
    }
    return classifyTransport(this, stack);
  }
}

extension StorageFailure on StorageException {
  Failure toFailure(StackTrace stack) {
    final text = '$statusCode $message'.toLowerCase();
    if (text.contains('413') || text.contains('too large')) {
      return const ReceiptTooLarge();
    }
    if (text.contains('403') || text.contains('401')) {
      return const StorageUnavailable();
    }
    return classifyTransport(this, stack);
  }
}

/// The refusals worth acting on, typed.
///
/// This classification lived in `domain/auth_rules.dart` as
/// `friendlyAuthMessage`, matching substrings of Supabase's English against
/// Portuguese replacements — the domain layer reading a library's error prose.
/// The matching has to happen somewhere, because the provider only offers
/// sentences; it belongs here, where knowing Supabase is the job.
extension AuthFailure on AuthException {
  Failure toFailure(StackTrace stack) {
    final text = message.toLowerCase();
    if (text.contains('invalid login credentials')) {
      return const InvalidCredentials();
    }
    if (text.contains('email not confirmed')) return const EmailNotConfirmed();
    if (text.contains('user already registered')) {
      return const EmailAlreadyRegistered();
    }
    if (text.contains('for security purposes') || text.contains('rate limit')) {
      return const TooManyAttempts();
    }
    // Supabase says "should be different from the old password"; older builds
    // said "same as the old password". Both mean the same refusal.
    if (text.contains('different from the old password') ||
        text.contains('same as the old password')) {
      return const PasswordUnchanged();
    }
    if (text.contains('jwt') || text.contains('expired')) {
      return const SessionExpired();
    }
    return AuthenticationFailure(message);
  }
}

/// The last resort for a `try` that wraps Supabase work.
///
/// Ordered so the typed branches win: an untyped `catch` that ran first would
/// classify every constraint violation as unexpected.
///
/// Named apart from `asFailure` in `core/errors` on purpose. That one is the
/// generic passthrough any layer may call; this one knows Postgrest and must
/// never be reachable from the presentation layer.
Failure supabaseFailure(Object error, StackTrace stack) => switch (error) {
  Failure() => error,
  PostgrestException() => error.toFailure(stack),
  StorageException() => error.toFailure(stack),
  AuthException() => error.toFailure(stack),
  _ => classifyTransport(error, stack),
};
