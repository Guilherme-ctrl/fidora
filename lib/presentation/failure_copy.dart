import 'package:financeiro_ai/core/errors/failure.dart';

/// A [Failure], phrased for the person reading the screen.
///
/// This file is the only place in the project that decides what a failure
/// *says*. It used to be five methods inside the Supabase repository — the
/// lowest layer writing the sentences of the highest — plus a sixth in the
/// domain classifying by substring. Moving it here is what makes translation
/// possible at all, and what lets a screen respond to the cause instead of to
/// a string.
class FailureCopy {
  const FailureCopy({
    required this.message,
    required this.hint,
    required this.detail,
    required this.canRetry,
  });

  /// One line saying what went wrong.
  final String message;

  /// What the person can do about it.
  final String hint;

  /// The original failure, for the technical-details disclosure.
  final String detail;

  final bool canRetry;

  /// Copy for a failure raised while loading.
  factory FailureCopy.of(Failure failure) => switch (failure) {
    DuplicateTransaction() => const FailureCopy(
      message: 'Este lançamento já existe no seu histórico',
      hint: 'Ele foi capturado antes, pelo Atalho ou por uma importação.',
      detail: 'DuplicateTransaction',
      canRetry: false,
    ),
    InvalidAmount() => const FailureCopy(
      message: 'O valor precisa ser maior que zero',
      hint: 'Confira o valor digitado.',
      detail: 'InvalidAmount',
      canRetry: false,
    ),
    DuplicateCard() => const FailureCopy(
      message: 'Já existe um cartão com esse final',
      hint: 'Dois cartões não podem dividir os mesmos quatro dígitos.',
      detail: 'DuplicateCard',
      canRetry: false,
    ),
    InvalidCardLastFour() => const FailureCopy(
      message: 'O final precisa ter exatamente 4 dígitos',
      hint: 'São os quatro últimos números impressos no cartão.',
      detail: 'InvalidCardLastFour',
      canRetry: false,
    ),
    InvalidCardDay() => const FailureCopy(
      message: 'Os dias de fechamento e vencimento vão de 1 a 31',
      hint: 'Confira as duas datas do cartão.',
      detail: 'InvalidCardDay',
      canRetry: false,
    ),
    DuplicateCategory() => const FailureCopy(
      message: 'Já existe uma categoria com esse nome',
      hint: 'Escolha outro nome, ou reative a categoria existente.',
      detail: 'DuplicateCategory',
      canRetry: false,
    ),
    DuplicateAccount() => const FailureCopy(
      message: 'Já existe uma conta com esse nome',
      hint: 'Escolha outro nome, ou reative a conta existente.',
      detail: 'DuplicateAccount',
      canRetry: false,
    ),
    DuplicateHolder() => const FailureCopy(
      message: 'Já existe um portador com esse nome',
      hint: 'Escolha outro nome.',
      detail: 'DuplicateHolder',
      canRetry: false,
    ),
    DuplicateMerchantRule() => const FailureCopy(
      message: 'Já existe uma regra para esse trecho',
      hint: 'Edite a regra existente em vez de criar uma segunda.',
      detail: 'DuplicateMerchantRule',
      canRetry: false,
    ),
    RecordNotFound(:final what) => FailureCopy(
      message: switch (what) {
        RecordKind.card => 'O cartão escolhido não está mais disponível',
        RecordKind.category => 'A categoria escolhida não existe mais',
        RecordKind.invoice => 'Fatura não encontrada',
        RecordKind.token => 'Token não encontrado',
        RecordKind.receipt => 'Comprovante não encontrado',
        RecordKind.transaction => 'Lançamento não encontrado',
      },
      hint: 'Ele pode ter sido removido em outra sessão. Atualize a tela.',
      detail: 'RecordNotFound.${what.name}',
      canRetry: true,
    ),
    ValidationFailure(:final message) => FailureCopy(
      message: message,
      hint: 'Corrija o campo destacado e tente de novo.',
      detail: 'ValidationFailure',
      canRetry: false,
    ),
    SessionExpired() => const FailureCopy(
      message: 'Sua sessão expirou',
      hint: 'Entre novamente para continuar.',
      detail: 'SessionExpired',
      canRetry: false,
    ),
    PermissionDenied() => const FailureCopy(
      message: 'Sem permissão para acessar estes dados',
      hint: 'Confirme que você entrou com a conta certa.',
      detail: 'PermissionDenied',
      canRetry: false,
    ),
    NetworkUnavailable() => const FailureCopy(
      message: 'Sem conexão com o servidor',
      hint: 'Verifique sua internet e tente novamente.',
      detail: 'NetworkUnavailable',
      canRetry: true,
    ),
    RequestTimeout() => const FailureCopy(
      message: 'O servidor demorou para responder',
      hint: 'Pode ser instabilidade momentânea. Tente de novo.',
      detail: 'RequestTimeout',
      canRetry: true,
    ),
    ReceiptTooLarge() => const FailureCopy(
      message: 'A imagem passa de 10 MB',
      hint: 'Tire a foto em resolução menor.',
      detail: 'ReceiptTooLarge',
      canRetry: false,
    ),
    StorageUnavailable() => const FailureCopy(
      message: 'Não foi possível guardar o comprovante',
      hint: 'Tente de novo em instantes.',
      detail: 'StorageUnavailable',
      canRetry: true,
    ),
    AuthenticationFailure(:final reason) => FailureCopy(
      message: reason,
      hint: 'Confira os dados e tente novamente.',
      detail: 'AuthenticationFailure',
      canRetry: false,
    ),
    UnexpectedFailure(:final cause) => FailureCopy(
      message: 'Não foi possível concluir a operação',
      hint: 'Tente novamente em instantes.',
      detail: '$cause',
      canRetry: true,
    ),
  };

  /// Copy for anything at all, typed or not.
  ///
  /// The loading path receives `Object` from the framework's error slot, so it
  /// cannot rely on a [Failure] having survived. It resolves through
  /// `core/errors`, never through `lib/data`: this file must not be able to
  /// name the database behind the repository.
  factory FailureCopy.from(Object error, [StackTrace? stack]) =>
      FailureCopy.of(asFailure(error, stack ?? StackTrace.current));

  /// The one-line form, for a snack bar or an inline field error.
  String get short => message;
}
