/// Validation for the sign-in and password-recovery screens.
///
/// Kept out of the widgets so the rules can be tested without a Supabase
/// session, and so the recovery screen cannot drift from the sign-up screen
/// about what counts as an acceptable password.
class AuthFieldErrors {
  const AuthFieldErrors({this.email, this.password, this.confirmation});
  final String? email;
  final String? password;
  final String? confirmation;

  bool get isEmpty => email == null && password == null && confirmation == null;
  String? get firstMessage => email ?? password ?? confirmation;
}

String? validateEmail(String value) {
  final email = value.trim();
  if (email.isEmpty) return 'Informe seu e-mail';
  // Deliberately permissive: the authoritative check is the delivery of the
  // message, and a stricter pattern only rejects valid addresses.
  final shape = RegExp(r'^[^@\s]+@[^@\s.]+\.[^@\s]+$');
  return shape.hasMatch(email) ? null : 'Informe um e-mail válido';
}

String? validatePassword(String value) {
  if (value.isEmpty) return 'Informe uma senha';
  if (value.length < 8) return 'Use pelo menos 8 caracteres';
  return null;
}

String? validateConfirmation(String password, String confirmation) {
  if (confirmation.isEmpty) return 'Repita a nova senha';
  return password == confirmation ? null : 'As senhas não coincidem';
}

AuthFieldErrors validateNewPassword(String password, String confirmation) =>
    AuthFieldErrors(
      password: validatePassword(password),
      confirmation: validateConfirmation(password, confirmation),
    );
