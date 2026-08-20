// Measures whether a CNAE lookup is worth building, using your own statement.
//
// Nothing leaves the machine and nothing is written down: it reads the file,
// counts, prints percentages, and exits. No merchant name and no document is
// printed, so the output is safe to paste into a conversation.
//
//   dart run tool/statement_coverage.dart ~/Downloads/extrato.csv
//   dart run tool/statement_coverage.dart ~/Downloads/*.csv
//
// Add --amostra to see a handful of *redacted* shapes, which is what you need
// if the coverage comes out low and you want to know why.

import 'dart:io';

import 'package:financeiro_ai/features/review/domain/merchant_identity.dart';

void main(List<String> args) {
  final files = args.where((a) => !a.startsWith('--')).toList();
  final wantsSample = args.contains('--amostra');

  if (files.isEmpty) {
    stdout.writeln('uso: dart run tool/statement_coverage.dart <extrato.csv>');
    exitCode = 64;
    return;
  }

  final coverage = PayeeCoverage();
  final shapes = <String, int>{};
  var lines = 0;

  for (final path in files) {
    final file = File(path);
    if (!file.existsSync()) {
      stderr.writeln('não encontrei: $path');
      continue;
    }
    for (final row in file.readAsLinesSync()) {
      final description = _description(row);
      if (description == null) continue;
      lines += 1;
      coverage.add(description);
      if (wantsSample) {
        final shape = _redact(description);
        shapes[shape] = (shapes[shape] ?? 0) + 1;
      }
    }
  }

  if (lines == 0) {
    stdout.writeln('nenhuma linha reconhecida — o arquivo é CSV?');
    exitCode = 65;
    return;
  }

  String pct(num part, num whole) =>
      whole == 0 ? '  —  ' : '${(100 * part / whole).toStringAsFixed(1)}%';

  stdout
    ..writeln('')
    ..writeln('Linhas lidas: ${coverage.total}')
    ..writeln(
      '  das quais Pix: ${coverage.pix} '
      '(${pct(coverage.pix, coverage.total)})',
    )
    ..writeln('')
    ..writeln('Com CNPJ válido, ramo consultável de graça:')
    ..writeln(
      '  ${coverage.resolvable} lançamentos '
      '(${pct(coverage.resolvable, coverage.total)} de tudo, '
      '${pct(coverage.resolvable, coverage.pix)} dos Pix)',
    )
    ..writeln(
      '  ${coverage.distinctCnpj.length} empresas distintas '
      '— é esse o número de consultas, não o de cima',
    )
    ..writeln('')
    ..writeln('O que não dá para resolver:')
    ..writeln(
      '  pessoa física (CPF):      '
      '${coverage.counts[PayeeKind.person]}',
    )
    ..writeln(
      '  documento mascarado:      '
      '${coverage.counts[PayeeKind.maskedPerson]}',
    )
    ..writeln(
      '  Pix só com nome:          '
      '${coverage.counts[PayeeKind.pixNameOnly]}',
    )
    ..writeln(
      '  cartão e o resto:         '
      '${coverage.counts[PayeeKind.other]}',
    )
    ..writeln('');

  final share = coverage.shareOfAll;
  stdout.writeln(switch (share) {
    >= 0.30 => 'Vale construir: a consulta alcança boa parte do extrato.',
    >= 0.10 =>
      'Zona cinzenta. Cobre uma fatia real, mas as regras de estabelecimento\n'
          'que você já cria na revisão podem cobrir o mesmo por menos trabalho.',
    _ =>
      'Não vale. Seu banco não escreve o documento na descrição, e casar nome\n'
          'com empresa é palpite. O MCC do cartão é o caminho melhor.',
  });

  if (wantsSample && shapes.isNotEmpty) {
    stdout.writeln('\nFormatos encontrados (dígitos e nomes trocados por #):');
    final ordered = shapes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final entry in ordered.take(12)) {
      stdout.writeln('  ${entry.value.toString().padLeft(4)} × ${entry.key}');
    }
  }
}

/// The longest non-numeric-looking field in a CSV row.
///
/// Deliberately dumb: every bank exports a different column order, and asking
/// someone to map columns before they know whether the idea works is the wrong
/// order of operations.
String? _description(String row) {
  if (row.trim().isEmpty) return null;
  // A header has no digits anywhere. Counting it as a transaction would tilt
  // the percentage by a whole line, and on a small statement that is visible.
  if (!RegExp(r'\d').hasMatch(row)) return null;
  final cells = row.split(RegExp(r'[;,\t]')).map((c) => c.trim()).toList();
  final best = cells
      .where((c) => c.length > 6 && RegExp(r'[A-Za-zÀ-ÿ]{3}').hasMatch(c))
      .fold<String?>(
        null,
        (longest, c) =>
            longest == null || c.length > longest.length ? c : longest,
      );
  return best;
}

/// Keeps the shape, drops the content.
String _redact(String value) => value
    .replaceAll(RegExp(r'\d'), '#')
    .replaceAll(RegExp(r'[A-Za-zÀ-ÿ]{2,}'), 'AAA')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
