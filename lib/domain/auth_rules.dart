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

/// Turns a Supabase auth failure into something worth reading.
String friendlyAuthMessage(String raw) {
  final text = raw.toLowerCase();
  if (text.contains('invalid login credentials')) {
    return 'E-mail ou senha incorretos.';
  }
  if (text.contains('email not confirmed')) {
    return 'Confirme seu e-mail antes de entrar.';
  }
  if (text.contains('user already registered')) {
    return 'Já existe uma conta com este e-mail.';
  }
  if (text.contains('for security purposes') || text.contains('rate limit')) {
    return 'Muitas tentativas seguidas. Aguarde um minuto e tente de novo.';
  }
  // Supabase says "should be different from the old password"; older builds
  // said "same as the old password". Both mean the same refusal.
  if (text.contains('different from the old password') ||
      text.contains('same as the old password')) {
    return 'A nova senha precisa ser diferente da anterior.';
  }
  return raw;
}
