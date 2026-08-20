/// Inputs for the catalogue screens — cards and categories — with the same
/// per-field validation shape the transaction form already uses, so the
/// widgets bind errors directly instead of re-deriving the rules.
library;

class CardDraftErrors {
  const CardDraftErrors({
    this.name,
    this.bank,
    this.lastFour,
    this.closingDay,
    this.dueDay,
    this.limit,
  });
  final String? name;
  final String? bank;
  final String? lastFour;
  final String? closingDay;
  final String? dueDay;
  final String? limit;

  bool get isEmpty =>
      name == null &&
      bank == null &&
      lastFour == null &&
      closingDay == null &&
      dueDay == null &&
      limit == null;

  String? get firstMessage =>
      name ?? bank ?? lastFour ?? closingDay ?? dueDay ?? limit;
}

class CardDraft {
  const CardDraft({
    required this.name,
    required this.bank,
    required this.lastFour,
    required this.closingDay,
    required this.dueDay,
    this.id,
    this.limit = 0,
    this.holder = '',
    this.holderId,
    this.includeInTotals = true,
    this.active = true,
  });

  final String? id;
  final String name;
  final String bank;
  final String lastFour;
  final int closingDay;
  final int dueDay;
  final double limit;
  final String holder;
  final String? holderId;
  final bool includeInTotals;
  final bool active;

  bool get isEdit => id != null;

  CardDraftErrors validate() => CardDraftErrors(
    name: name.trim().isEmpty ? 'Dê um nome ao cartão' : null,
    bank: bank.trim().isEmpty ? 'Informe o banco' : null,
    // The column is checked against exactly four digits, and the Shortcut
    // matches on it, so a wrong final silently sends captures nowhere.
    lastFour: RegExp(r'^\d{4}$').hasMatch(lastFour.trim())
        ? null
        : 'O final tem exatamente 4 dígitos',
    closingDay: _day(closingDay, 'fechamento'),
    dueDay: _day(dueDay, 'vencimento'),
    limit: limit < 0 ? 'O limite não pode ser negativo' : null,
  );

  static String? _day(int value, String label) =>
      value >= 1 && value <= 31 ? null : 'O dia de $label vai de 1 a 31';
}

class GoalDraftErrors {
  const GoalDraftErrors({this.name, this.target, this.current});
  final String? name;
  final String? target;
  final String? current;
  bool get isEmpty => name == null && target == null && current == null;
  String? get firstMessage => name ?? target ?? current;
}

class GoalDraft {
  const GoalDraft({
    required this.name,
    required this.target,
    this.id,
    this.current = 0,
    this.targetDate,
    this.active = true,
  });

  final String? id;
  final String name;
  final double target;
  final double current;
  final DateTime? targetDate;
  final bool active;

  bool get isEdit => id != null;

  GoalDraftErrors validate() => GoalDraftErrors(
    name: name.trim().isEmpty ? 'Dê um nome à meta' : null,
    // The column checks target_amount > 0, so a zero target is refused by the
    // database anyway; catching it here says why.
    target: switch (target) {
      final value when value.isNaN => 'Informe um valor',
      <= 0 => 'A meta precisa ser maior que zero',
      _ => null,
    },
    current: switch (current) {
      final value when value.isNaN => 'Informe um valor',
      < 0 => 'O valor atual não pode ser negativo',
      _ => null,
    },
  );
}

class AccountDraftErrors {
  const AccountDraftErrors({this.name, this.openingBalance});
  final String? name;
  final String? openingBalance;
  bool get isEmpty => name == null && openingBalance == null;
  String? get firstMessage => name ?? openingBalance;
}

class AccountDraft {
  const AccountDraft({
    required this.name,
    this.id,
    this.bank = '',
    this.type = 'checking',
    this.openingBalance = 0,
    this.includeInTotals = true,
    this.active = true,
  });

  final String? id;
  final String name;
  final String bank;
  final String type;
  final double openingBalance;
  final bool includeInTotals;
  final bool active;

  bool get isEdit => id != null;

  AccountDraftErrors validate() => AccountDraftErrors(
    name: name.trim().isEmpty ? 'Dê um nome à conta' : null,
    // A negative opening balance is legitimate — an overdraft — so only a
    // non-number is refused.
    openingBalance: openingBalance.isNaN ? 'Informe um valor válido' : null,
  );
}

const accountTypes = <String, String>{
  'checking': 'Conta corrente',
  'savings': 'Poupança',
  'wallet': 'Carteira',
  'investment': 'Investimento',
};

class HolderDraftErrors {
  const HolderDraftErrors({this.name});
  final String? name;
  bool get isEmpty => name == null;
  String? get firstMessage => name;
}

class HolderDraft {
  const HolderDraft({required this.name, this.id, this.includeInTotals = true});
  final String? id;
  final String name;
  final bool includeInTotals;
  bool get isEdit => id != null;

  HolderDraftErrors validate() => HolderDraftErrors(
    name: name.trim().isEmpty ? 'Informe o nome do portador' : null,
  );
}

class CategoryDraftErrors {
  const CategoryDraftErrors({this.name, this.budget});
  final String? name;
  final String? budget;
  bool get isEmpty => name == null && budget == null;
  String? get firstMessage => name ?? budget;
}

class CategoryDraft {
  const CategoryDraft({
    required this.name,
    required this.colorHex,
    required this.iconName,
    this.id,
    this.monthlyBudget,
    this.sortOrder = 0,
    this.active = true,
  });

  final String? id;
  final String name;

  /// `#RRGGBB`. See [FinanceCategory.colorHex].
  final String colorHex;
  final String iconName;

  /// Null means the category has no budget, which is different from zero.
  final double? monthlyBudget;
  final int sortOrder;
  final bool active;

  bool get isEdit => id != null;

  CategoryDraftErrors validate() => CategoryDraftErrors(
    name: switch (name.trim()) {
      '' => 'Dê um nome à categoria',
      final value when value.length < 2 => 'Use ao menos 2 caracteres',
      _ => null,
    },
    budget: switch (monthlyBudget) {
      null => null,
      final value when value.isNaN => 'Informe um valor válido',
      final value when value < 0 => 'O orçamento não pode ser negativo',
      _ => null,
    },
  );
}
