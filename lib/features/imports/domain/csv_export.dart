import 'package:financeiro_ai/features/ledger/domain/entities/models.dart';
import 'package:intl/intl.dart';

/// Builds the CSV the export screen hands over.
///
/// The format targets the spreadsheet these numbers came from: semicolon
/// separators and comma decimals, which is what Excel and Google Sheets expect
/// in pt-BR. Using commas for both would make every row split in the wrong
/// places the moment someone opens the file here.
String buildTransactionsCsv(
  FinanceSnapshot snapshot,
  List<FinanceTransaction> transactions, {
  String separator = ';',
}) {
  final date = DateFormat('dd/MM/yyyy');
  final month = DateFormat('MM/yyyy');
  final accountNames = {
    for (final account in snapshot.accounts) account.id: account.name,
  };

  final rows = <List<String>>[
    const [
      'Data',
      'Estabelecimento',
      'Categoria',
      'Valor',
      'Sua parte',
      'Cartão',
      'Conta',
      'Competência',
      'Parcela',
      'Situação',
      'Origem',
    ],
    ...transactions.map(
      (item) => [
        date.format(item.date),
        item.merchant,
        item.category,
        _money(item.amount),
        // Repeating the amount when nothing was split keeps the column
        // summable without the reader having to fill blanks.
        _money(item.personalShare),
        item.isCard ? item.cardLastFour : '',
        item.isCard ? '' : (accountNames[item.accountId] ?? ''),
        item.competence == null ? '' : month.format(item.competence!),
        item.isInstallment
            ? '${item.installmentCurrent}/${item.installmentTotal}'
            : '',
        switch (item.status) {
          TransactionStatus.confirmed => 'Confirmado',
          TransactionStatus.pending => 'Pendente',
          TransactionStatus.ignored => 'Ignorado',
        },
        item.source,
      ],
    ),
  ];

  final body = rows
      .map((row) => row.map((cell) => _escape(cell, separator)).join(separator))
      .join('\r\n');

  // The byte order mark is what stops Excel from rendering accented merchant
  // names as mojibake.
  return '﻿$body\r\n';
}

String _money(double value) => value.toStringAsFixed(2).replaceAll('.', ',');

/// Quotes a field when it would otherwise break the row, doubling any quotes
/// inside it, as RFC 4180 expects.
String _escape(String value, String separator) {
  final needsQuotes =
      value.contains(separator) ||
      value.contains('"') ||
      value.contains('\n') ||
      value.contains('\r');
  if (!needsQuotes) return value;
  return '"${value.replaceAll('"', '""')}"';
}

/// A file name that sorts chronologically and says what it holds.
String csvFileName(DateTime now) =>
    'finora-${DateFormat('yyyy-MM-dd').format(now)}.csv';
