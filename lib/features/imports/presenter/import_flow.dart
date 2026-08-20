import 'package:financeiro_ai/core/platform/file_access.dart';
import 'package:financeiro_ai/core/theme/theme.dart';
import 'package:financeiro_ai/features/imports/domain/invoice_import.dart';
import 'package:financeiro_ai/features/imports/domain/statement_import.dart';
import 'package:financeiro_ai/features/imports/domain/statement_sheet.dart';
import 'package:financeiro_ai/features/imports/domain/usecases/import_invoice.dart';
import 'package:financeiro_ai/features/imports/infra/xlsx_reader.dart';
import 'package:financeiro_ai/features/imports/presenter/widgets/invoice_review_dialog.dart';
import 'package:financeiro_ai/features/imports/presenter/widgets/statement_context_sheet.dart';
import 'package:financeiro_ai/features/ledger/domain/entities/models.dart';
import 'package:financeiro_ai/features/ledger/domain/repositories/repositories.dart';
import 'package:financeiro_ai/features/ledger/presenter/cubits/finance_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Choosing a file, reviewing what it holds, and writing it.
///
/// This was 150 lines inside `MorePage` — the settings menu, which also
/// happened to be the import engine and the router for nine other screens.
/// The orchestration is here, in the feature it belongs to; the decision about
/// whether a reviewed document may be written is in
/// `ImportInvoiceUseCase.mayImport`, which is where it can be tested.

const _jsonType = FileTypeFilter(
  label: 'JSON do Finora',
  extensions: ['json'],
  mimeTypes: ['application/json'],
  uniformTypeIdentifiers: ['public.json'],
);

const _sheetType = FileTypeFilter(
  label: 'Extrato (CSV ou XLSX)',
  extensions: ['csv', 'txt', 'xlsx'],
);

/// Reads the JSON the app itself exports.
Future<void> pickInvoiceImport(
  BuildContext context, {
  required FinanceSnapshot snapshot,
}) async {
  final picker = context.read<FilePicker>();
  try {
    final picked = await picker.pickFile(accept: const [_jsonType]);
    if (picked == null || !context.mounted) return;
    await _run(context, decodeInvoiceDocument(picked.bytes), snapshot);
  } on InvoiceImportException catch (error) {
    if (context.mounted) _say(context, error.message, error: true);
  } catch (error) {
    if (context.mounted) _say(context, importErrorCopy(error), error: true);
  }
}

/// Reads a bank's own spreadsheet export, so the ledger stops depending on a
/// JSON produced outside the app.
Future<void> pickStatementImport(
  BuildContext context, {
  required FinanceSnapshot snapshot,
}) async {
  final picker = context.read<FilePicker>();
  try {
    final picked = await picker.pickFile(accept: const [_sheetType]);
    if (picked == null || !context.mounted) return;

    final parse = parseStatementBytes(
      bytes: picked.bytes,
      fileName: picked.name,
      readXlsx: readXlsxCells,
    );
    if (!context.mounted) return;

    final statementContext = await askStatementContext(
      context,
      cards: snapshot.cards,
      parse: parse,
      fileName: picked.name,
    );
    if (statementContext == null || !context.mounted) return;

    await _run(
      context,
      buildStatementImport(parse, statementContext),
      snapshot,
    );
  } on StatementParseException catch (error) {
    if (context.mounted) _say(context, error.message, error: true);
  } on InvoiceImportException catch (error) {
    if (context.mounted) _say(context, error.message, error: true);
  } catch (error) {
    if (context.mounted) _say(context, importErrorCopy(error), error: true);
  }
}

/// Preview, review and write. Shared by both readers on purpose: a second path
/// into the ledger would be a second place for the duplicate check and the
/// category rules to drift.
Future<void> _run(
  BuildContext context,
  InvoiceImportDocument document,
  FinanceSnapshot snapshot,
) async {
  final useCase = ImportInvoiceUseCase(context.read<InvoiceRepository>());
  final finance = context.read<FinanceCubit>();
  var loadingOpen = false;
  try {
    _showLoading(context, 'Validando e conciliando…');
    loadingOpen = true;
    final preview = await useCase.preview(document);
    if (!context.mounted) return;
    _closeLoading(context);
    loadingOpen = false;

    final reviewed = await showInvoiceReviewDialog(
      context,
      document: document,
      preview: preview,
      categories: snapshot.categories,
    );
    if (reviewed == null || !context.mounted) return;

    _showLoading(context, 'Conferindo revisão…');
    loadingOpen = true;
    // The second check and the write are one call now: they were two steps
    // with the rule spelled out between them, and the rule is the use case's.
    final result = await useCase.commit(reviewed);
    await finance.reloadAll();
    if (!context.mounted) return;
    _closeLoading(context);
    loadingOpen = false;

    _say(
      context,
      result.duplicateBatch
          ? 'Esta fatura já havia sido importada.'
          : 'Fatura importada: ${result.created} novos, '
                '${result.reconciled} conciliados e '
                '${result.reviews} para revisão.',
    );
  } on InvoiceImportException catch (error) {
    if (context.mounted) {
      if (loadingOpen) _closeLoading(context);
      _say(context, error.message, error: true);
    }
  } catch (error) {
    if (context.mounted) {
      if (loadingOpen) _closeLoading(context);
      _say(context, importErrorCopy(error), error: true);
    }
  }
}

void _showLoading(BuildContext context, String label) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      content: Row(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    ),
  );
}

void _closeLoading(BuildContext context) {
  final navigator = Navigator.of(context, rootNavigator: true);
  if (navigator.canPop()) navigator.pop();
}

void _say(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: error ? context.palette.negative : context.palette.income,
    ),
  );
}

/// The Edge Function's refusal codes, phrased for a person.
///
/// Substring matching, and it stays that way: these are the import RPC's own
/// codes, a contract between this app and its backend, not a library's error
/// prose. It sits in the presentation layer, which is the layer that owns copy.
String importErrorCopy(Object error) {
  final text = '$error';
  if (text.contains('card_not_found')) {
    return 'O cartão final informado no JSON não está cadastrado ou está inativo.';
  }
  if (text.contains('missing_categories')) {
    return 'O JSON usa categorias que ainda não existem no Finora.';
  }
  if (text.contains('reconciled_total_mismatch')) {
    return 'A conciliação não fechou com o total da fatura. Nada foi importado.';
  }
  if (text.contains('personal_total_mismatch')) {
    return 'As decisões item a item não fecharam com o total pessoal. Nada foi importado.';
  }
  return 'Não foi possível importar: $text';
}
