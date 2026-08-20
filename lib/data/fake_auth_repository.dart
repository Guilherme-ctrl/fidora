import 'dart:async';

import 'package:financeiro_ai/core/errors/failure.dart';
import 'package:financeiro_ai/domain/auth_repository.dart';

/// An in-memory [AuthRepository], in the same spirit as
/// `DemoFinanceRepository`.
///
/// The ledger has had a complete double since the beginning, which is why its
/// write path is well tested. Authentication had none, which is why none of it
/// was tested at all.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({AuthSession? session, this.knownPassword = 'sen ha1234'})
    : _session = session;

  /// The password [signIn] accepts. Anything else is [InvalidCredentials].
  final String knownPassword;

  final _controller = StreamController<AuthChange>.broadcast();
  AuthSession? _session;
  final _registered = <String>{};

  @override
  Stream<AuthChange> changes() => _controller.stream;

  @override
  AuthSession? get currentSession => _session;

  void _emit(AuthEvent event) =>
      _controller.add(AuthChange(event: event, session: _session));

  /// Drives the recovery branch, which no test could reach before.
  void emitPasswordRecovery() {
    _session = const AuthSession(userId: 'u1', email: 'quem@exemplo.com');
    _emit(AuthEvent.passwordRecovery);
  }

  @override
  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
  }) async {
    if (!_registered.add(email)) throw const EmailAlreadyRegistered();
    return SignUpOutcome.confirmationRequired;
  }

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    if (password != knownPassword) throw const InvalidCredentials();
    _session = AuthSession(userId: 'u1', email: email);
    _emit(AuthEvent.signedIn);
  }

  @override
  Future<void> signOut() async {
    _session = null;
    _emit(AuthEvent.signedOut);
  }

  /// Says nothing about whether the address exists, which is the rule the
  /// contract states and the reason this cannot report a failure.
  @override
  Future<void> sendPasswordRecovery(String email) async {}

  @override
  Future<void> updatePassword(String password) async {
    if (password == knownPassword) throw const PasswordUnchanged();
  }

  void dispose() => _controller.close();
}
