import 'package:flutter/material.dart';

/// Inputs for the catalogue screens — cards and categories — with the same
/// per-field validation shape the transaction form already uses, so the
/// widgets bind errors directly instead of re-deriving the rules.

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
    required this.color,
    required this.iconName,
    this.id,
    this.monthlyBudget,
    this.sortOrder = 0,
    this.active = true,
  });

  final String? id;
  final String name;
  final Color color;
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
