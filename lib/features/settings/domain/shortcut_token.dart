import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// A token the iOS Shortcut sends in `x-shortcut-token`.
///
/// Only the SHA-256 hash is ever stored. The secret itself exists once, in the
/// moment it is generated, and is never recoverable — losing it means issuing a
/// new one, which is the correct trade for a credential that can write to the
/// ledger.
class ShortcutToken {
  const ShortcutToken({
    required this.id,
    required this.name,
    required this.createdAt,
    this.lastUsedAt,
    this.revokedAt,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime? lastUsedAt;
  final DateTime? revokedAt;

  bool get isActive => revokedAt == null;
  bool get everUsed => lastUsedAt != null;

}

/// A freshly issued token: the secret to show once, and the row that was saved.
class IssuedShortcutToken {
  const IssuedShortcutToken({required this.secret, required this.token});
  final String secret;
  final ShortcutToken token;
}

/// 32 bytes from the platform's secure generator, URL-safe so it survives being
/// pasted into a Shortcut field.
String generateShortcutSecret() {
  final random = Random.secure();
  final bytes = List<int>.generate(32, (_) => random.nextInt(256));
  return base64UrlEncode(bytes).replaceAll('=', '');
}

/// Must match the hashing in the `capture-transaction` Edge Function, which
/// hex-encodes the SHA-256 of the raw header value.
String hashShortcutSecret(String secret) =>
    sha256.convert(utf8.encode(secret)).toString();

class ShortcutTokenErrors {
  const ShortcutTokenErrors({this.name});
  final String? name;
  bool get isEmpty => name == null;
  String? get firstMessage => name;
}

ShortcutTokenErrors validateTokenName(String name) => ShortcutTokenErrors(
  name: switch (name.trim()) {
    '' => 'Dê um nome para reconhecer este token depois',
    final value when value.length < 3 => 'Use ao menos 3 caracteres',
    _ => null,
  },
);
