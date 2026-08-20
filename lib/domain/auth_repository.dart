/// Who is signed in, and how that changes.
///
/// The app had no such contract. `Supabase.instance.client.auth` was called
/// from four places inside widgets, `AuthException` was caught in the UI, and
/// the whole sign-in surface could not be exercised without a real Supabase —
/// the only data path in the project that had not been inverted, while the
/// ledger beside it had a full in-memory double.
library;

/// The signed-in person, reduced to what the app actually uses.
///
/// Deliberately not Supabase's `Session`: nothing above this layer needs the
/// access token, the refresh token or the expiry, and carrying them would put
/// credentials in reach of every widget that reads a session.
class AuthSession {
  const AuthSession({required this.userId, required this.email});
  final String userId;
  final String email;
}

/// What just happened to the session.
enum AuthEvent {
  signedIn,
  signedOut,

  /// A recovery link signed the person in so they can choose a new password.
  /// Without this case the app drops them on the dashboard with no way to set
  /// one.
  passwordRecovery,

  /// The token was renewed. Carries a session and changes nothing on screen.
  tokenRefreshed,
}

class AuthChange {
  const AuthChange({required this.event, this.session});
  final AuthEvent event;
  final AuthSession? session;
}

/// What signing up produced.
enum SignUpOutcome {
  /// The account exists and the person is in.
  signedIn,

  /// The account exists and is waiting on an e-mail confirmation.
  confirmationRequired,
}

abstract interface class AuthRepository {
  /// Emits on every change, including the first state after start-up.
  Stream<AuthChange> changes();

  /// The session right now, or null when signed out.
  AuthSession? get currentSession;

  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
  });

  Future<void> signIn({required String email, required String password});

  Future<void> signOut();

  /// Sends the recovery message.
  ///
  /// Implementations must answer the same way whether or not the address has
  /// an account, so this cannot be used to discover which e-mails are
  /// registered.
  Future<void> sendPasswordRecovery(String email);

  Future<void> updatePassword(String password);
}
