import 'package:financeiro_ai/features/ledger/infra/supabase_failures.dart';
import 'package:financeiro_ai/features/auth/domain/repositories/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// [AuthRepository] over Supabase.
///
/// The client is a constructor argument, not `Supabase.instance`. That is the
/// whole point of the file: the singleton was reachable from any widget, so
/// nothing about sign-in could be tested and nothing could be substituted.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  GoTrueClient get _auth => _client.auth;

  @override
  Stream<AuthChange> changes() => _auth.onAuthStateChange.map(
    (state) => AuthChange(
      event: switch (state.event) {
        AuthChangeEvent.passwordRecovery => AuthEvent.passwordRecovery,
        AuthChangeEvent.signedOut => AuthEvent.signedOut,
        AuthChangeEvent.tokenRefreshed => AuthEvent.tokenRefreshed,
        _ => AuthEvent.signedIn,
      },
      session: _sessionOf(state.session),
    ),
  );

  @override
  AuthSession? get currentSession => _sessionOf(_auth.currentSession);

  static AuthSession? _sessionOf(Session? session) {
    final user = session?.user;
    if (user == null) return null;
    return AuthSession(userId: user.id, email: user.email ?? '');
  }

  @override
  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
  }) => _guard(() async {
    final response = await _auth.signUp(email: email, password: password);
    // A null session means the project requires e-mail confirmation. It is an
    // outcome, not a failure, and the screen has to say something different
    // for it.
    return response.session == null
        ? SignUpOutcome.confirmationRequired
        : SignUpOutcome.signedIn;
  });

  @override
  Future<void> signIn({required String email, required String password}) =>
      _guard(() => _auth.signInWithPassword(email: email, password: password));

  @override
  Future<void> signOut() => _guard(_auth.signOut);

  @override
  Future<void> sendPasswordRecovery(String email) =>
      _guard(() => _auth.resetPasswordForEmail(email));

  @override
  Future<void> updatePassword(String password) =>
      _guard(() => _auth.updateUser(UserAttributes(password: password)));

  /// The single place `AuthException` is allowed to exist.
  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } catch (error, stack) {
      throw supabaseFailure(error, stack);
    }
  }
}
