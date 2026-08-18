/// A load failure translated for the person, keeping the raw text available for
/// whoever has to debug it.
///
/// The write path already did this; the loading path was still handing a
/// `PostgrestException` straight to a `Text` widget.
class LoadFailure {
  const LoadFailure({
    required this.message,
    required this.hint,
    required this.detail,
    required this.canRetry,
  });

  /// One line saying what went wrong.
  final String message;

  /// What the person can do about it.
  final String hint;

  /// The original error, for the technical-details disclosure.
  final String detail;

  final bool canRetry;

  factory LoadFailure.from(Object error) {
    final raw = '$error';
    final text = raw.toLowerCase();

    // Checked before the connection branch: "Connection timed out" matches
    // both, and the timeout is the more specific diagnosis.
    if (text.contains('timeout') || text.contains('timed out')) {
      return LoadFailure(
        message: 'O servidor demorou para responder',
        hint: 'Pode ser instabilidade momentânea. Tente de novo.',
        detail: raw,
        canRetry: true,
      );
    }
    if (text.contains('socketexception') ||
        text.contains('failed host lookup') ||
        text.contains('clientexception') ||
        text.contains('connection') ||
        text.contains('network')) {
      return LoadFailure(
        message: 'Sem conexão com o servidor',
        hint: 'Verifique sua internet e tente novamente.',
        detail: raw,
        canRetry: true,
      );
    }
    if (text.contains('jwt') ||
        text.contains('expired') ||
        text.contains('not authenticated') ||
        text.contains('invalid_token')) {
      return LoadFailure(
        message: 'Sua sessão expirou',
        hint: 'Entre novamente para continuar.',
        detail: raw,
        canRetry: false,
      );
    }
    if (text.contains('row-level security') || text.contains('42501')) {
      return LoadFailure(
        message: 'Sem permissão para ler estes dados',
        hint: 'Confirme que você entrou com a conta certa.',
        detail: raw,
        canRetry: false,
      );
    }
    return LoadFailure(
      message: 'Não foi possível carregar seus dados',
      hint: 'Tente novamente em instantes.',
      detail: raw,
      canRetry: true,
    );
  }
}
