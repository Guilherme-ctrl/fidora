import 'package:financeiro_ai/domain/models.dart';

/// Errors collected per form field so the UI can bind them directly to
/// `TextFormField.validator` without re-deriving the rules.
class TransactionDraftErrors {
  const TransactionDraftErrors({
    this.merchant,
    this.amount,
    this.category,
    this.installment,
    this.share,
  });

  final String? merchant;
  final String? amount;
  final String? category;
  final String? installment;
  final String? share;

  bool get isEmpty =>
      merchant == null &&
      amount == null &&
      category == null &&
      installment == null &&
      share == null;

  String? get firstMessage =>
      merchant ?? amount ?? category ?? installment ?? share;
}

/// Input for creating or editing a transaction. Editing carries [id]; creating
/// leaves it null.
class TransactionDraft {
  const TransactionDraft({
    required this.purchasedAt,
    required this.merchant,
    required this.amount,
    required this.categoryId,
    this.id,
    this.cardId,
    this.movementType = 'purchase',
    this.installmentCurrent,
    this.installmentTotal,
    this.status = TransactionStatus.confirmed,
    this.notes,
    this.holderId,
    this.personalAmount,
    this.accountId,
    this.receiptPath,
  });

  final String? id;
  final DateTime purchasedAt;
  final String merchant;
  final double amount;
  final String categoryId;
  final String? cardId;
  final String movementType;
  final int? installmentCurrent;
  final int? installmentTotal;
  final TransactionStatus status;
  final String? notes;
  final String? holderId;

  /// Your share of [amount]; null means all of it.
  final double? personalAmount;

  /// Where the money moved, when it was not a card.
  final String? accountId;

  /// Storage path of an attached receipt, or null. Already uploaded by the
  /// time the draft is saved: the write must not depend on a second network
  /// call that could fail after the row exists.
  final String? receiptPath;

  bool get isShared => personalAmount != null && personalAmount! < amount;

  bool get isEdit => id != null;
  bool get isCard => cardId != null;
  bool get isInstallment => (installmentTotal ?? 0) > 1;

  /// The `modality` check constraint accepts cash, installment and recurring.
  String get modality => isInstallment ? 'installment' : 'cash';

  TransactionDraftErrors validate() => TransactionDraftErrors(
    merchant: merchant.trim().isEmpty ? 'Informe o estabelecimento' : null,
    amount: switch (amount) {
      final value when value.isNaN || value.isInfinite => 'Informe um valor',
      <= 0 => 'O valor precisa ser maior que zero',
      _ => null,
    },
    category: categoryId.trim().isEmpty ? 'Escolha uma categoria' : null,
    installment: _installmentError(),
    share: switch (personalAmount) {
      null => null,
      final value when value.isNaN => 'Informe a sua parte',
      < 0 => 'A sua parte não pode ser negativa',
      // The column is constrained the same way; catching it here says why.
      final value when value > amount =>
        'A sua parte não pode passar do valor total',
      _ => null,
    },
  );

  String? _installmentError() {
    final total = installmentTotal;
    final current = installmentCurrent;
    if (total == null && current == null) return null;
    if (total == null || current == null) {
      return 'Informe a parcela atual e o total de parcelas';
    }
    if (total < 2) return 'Um parcelamento precisa de ao menos 2 parcelas';
    if (current < 1) return 'A parcela atual começa em 1';
    if (current > total) {
      return 'A parcela atual não pode ser maior que o total';
    }
    return null;
  }

  TransactionDraft copyWith({
    DateTime? purchasedAt,
    String? merchant,
    double? amount,
    String? categoryId,
    String? cardId,
    String? movementType,
    int? installmentCurrent,
    int? installmentTotal,
    TransactionStatus? status,
    String? notes,
    bool clearCard = false,
    bool clearInstallment = false,
  }) => TransactionDraft(
    id: id,
    purchasedAt: purchasedAt ?? this.purchasedAt,
    merchant: merchant ?? this.merchant,
    amount: amount ?? this.amount,
    categoryId: categoryId ?? this.categoryId,
    cardId: clearCard ? null : (cardId ?? this.cardId),
    movementType: movementType ?? this.movementType,
    installmentCurrent: clearInstallment
        ? null
        : (installmentCurrent ?? this.installmentCurrent),
    installmentTotal: clearInstallment
        ? null
        : (installmentTotal ?? this.installmentTotal),
    status: status ?? this.status,
    notes: notes ?? this.notes,
  );
}
