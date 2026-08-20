import 'dart:typed_data';

import 'package:financeiro_ai/application/providers.dart';
import 'package:financeiro_ai/application/receipt_recognizer.dart';
import 'package:financeiro_ai/core/platform/file_access.dart';
import 'package:financeiro_ai/core/theme.dart';
import 'package:financeiro_ai/data/demo_finance_repository.dart';
import 'package:financeiro_ai/domain/models.dart';
import 'package:financeiro_ai/domain/receipt_scan.dart';
import 'package:financeiro_ai/domain/transaction_draft.dart';
import 'package:financeiro_ai/presentation/widgets/receipt_field.dart';
import 'package:financeiro_ai/presentation/widgets/transaction_form_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Hands back a fixed image instead of opening a camera.
///
/// `ImagePicker()` used to be constructed inside the widget, so no test could
/// reach the branch that follows a successful pick — the one that reads the
/// bytes, runs recognition and reports the attachment upward.
class _FakeCapture implements ImageCapture {
  _FakeCapture(this.result);

  final PickedFile? result;
  final origins = <ImageOrigin>[];

  @override
  bool supports(ImageOrigin origin) => true;

  @override
  Future<PickedFile?> pick(
    ImageOrigin origin, {
    int maxWidth = 2000,
    int quality = 85,
  }) async {
    origins.add(origin);
    return result;
  }
}

/// Reports itself as available so the form takes the recognizing path, without
/// touching a camera or a native model.
class _FakeRecognizer implements ReceiptRecognizer {
  @override
  bool get isSupported => true;

  @override
  Future<ReceiptScan> scan(String imagePath) async => const ReceiptScan.empty();

  @override
  Future<void> dispose() async {}
}

FinanceSnapshot _snapshot() => const FinanceSnapshot(
  transactions: [],
  categories: [
    FinanceCategory(
      id: 'c1',
      name: 'Alimentação',
      iconName: 'category',
      colorHex: '#B23F22',
    ),
  ],
  cards: [],
  invoices: [],
  goals: [],
  pendingReviews: 0,
);

Future<void> _pumpField(
  WidgetTester tester, {
  PendingReceipt? pending,
  String? existingPath,
  ReceiptRecognizer? recognizer,
  ImageCapture? capture,
  ValueChanged<ReceiptScan>? onApply,
  VoidCallback? onCleared,
  ValueChanged<PendingReceipt>? onPicked,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        financeRepositoryProvider.overrideWithValue(DemoFinanceRepository()),
        receiptRecognizerProvider.overrideWithValue(
          recognizer ?? const UnavailableReceiptRecognizer(),
        ),
        if (capture != null) imageCaptureProvider.overrideWithValue(capture),
      ],
      child: MaterialApp(
        theme: buildAppTheme(brightness: Brightness.light),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ReceiptField(
              existingPath: existingPath,
              pending: pending,
              onPicked: onPicked ?? (_) {},
              onCleared: onCleared ?? () {},
              onApplyScan: onApply ?? (_) {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// A one-pixel PNG, so the preview has something real to decode.
final _png = Uint8List.fromList([
  137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, //
  0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137, //
  0, 0, 0, 13, 73, 68, 65, 84, 120, 156, 99, 250, 207, 0, 0, 3, 1, 1, 0, //
  24, 221, 141, 219, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130,
]);

PendingReceipt _pending({ReceiptScan? scan}) => PendingReceipt(
  bytes: _png,
  fileName: 'nota.png',
  contentType: 'image/png',
  scan: scan,
);

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  group('ReceiptField', () {
    testWidgets('offers both ways of getting an image', (tester) async {
      await _pumpField(tester);

      expect(find.text('Fotografar'), findsOneWidget);
      expect(find.text('Escolher imagem'), findsOneWidget);
      expect(find.text('Remover'), findsNothing);
    });

    testWidgets('says plainly that the web cannot read the image', (
      tester,
    ) async {
      await _pumpField(tester);

      expect(
        find.textContaining('só funciona no aplicativo do celular'),
        findsOneWidget,
      );
    });

    testWidgets('promises reading only where reading works', (tester) async {
      await _pumpField(tester, recognizer: _FakeRecognizer());

      expect(find.textContaining('Fotografe a nota'), findsOneWidget);
    });

    testWidgets('a chosen photograph reaches the form', (tester) async {
      // Unreachable before: the widget built its own ImagePicker, so the whole
      // path after a successful pick had no test at all.
      final capture = _FakeCapture(
        PickedFile(name: 'nota.png', bytes: _png, mimeType: 'image/png'),
      );
      PendingReceipt? picked;
      await _pumpField(
        tester,
        capture: capture,
        onPicked: (receipt) => picked = receipt,
      );

      await tester.tap(find.text('Fotografar'));
      await tester.pumpAndSettle();

      expect(capture.origins, [ImageOrigin.camera]);
      expect(picked?.fileName, 'nota.png');
      expect(picked?.contentType, 'image/png');
    });

    testWidgets('cancelling the picker is not a failure', (tester) async {
      final capture = _FakeCapture(null);
      PendingReceipt? picked;
      await _pumpField(
        tester,
        capture: capture,
        onPicked: (receipt) => picked = receipt,
      );

      await tester.tap(find.text('Escolher imagem'));
      await tester.pumpAndSettle();

      expect(capture.origins, [ImageOrigin.gallery]);
      expect(picked, isNull);
      expect(find.textContaining('Não foi possível'), findsNothing);
    });

    testWidgets('shows what was read and offers to apply it', (tester) async {
      await _pumpField(
        tester,
        recognizer: _FakeRecognizer(),
        pending: _pending(
          scan: ReceiptScan(
            rawText: 'x',
            merchant: 'PADARIA CENTRAL',
            amount: 24.80,
            date: DateTime(2026, 8, 15),
          ),
        ),
      );

      expect(
        find.textContaining('Li na nota: PADARIA CENTRAL'),
        findsOneWidget,
      );
      expect(find.text('Preencher os campos vazios'), findsOneWidget);
    });

    testWidgets('keeps the image when nothing could be read', (tester) async {
      await _pumpField(
        tester,
        recognizer: _FakeRecognizer(),
        pending: _pending(scan: const ReceiptScan.empty()),
      );

      // The attachment is useful on its own; a failed reading must not read as
      // a failed attachment.
      expect(find.textContaining('Não consegui ler nada'), findsOneWidget);
      expect(find.textContaining('fica anexada'), findsOneWidget);
      expect(find.text('Preencher os campos vazios'), findsNothing);
    });

    testWidgets('offers removal once something is attached', (tester) async {
      var cleared = false;
      await _pumpField(
        tester,
        pending: _pending(),
        onCleared: () => cleared = true,
      );

      await tester.tap(find.text('Remover'));
      expect(cleared, isTrue);
    });
  });

  group('applying a reading to the form', () {
    Future<void> pumpForm(
      WidgetTester tester,
      void Function(TransactionDraft) capture,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            financeRepositoryProvider.overrideWithValue(
              DemoFinanceRepository(),
            ),
            receiptRecognizerProvider.overrideWithValue(_FakeRecognizer()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showTransactionFormSheet(
                    context,
                    snapshot: _snapshot(),
                    onSave: (draft) async => capture(draft),
                  ),
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
    }

    testWidgets('the form carries no receipt path when none was attached', (
      tester,
    ) async {
      TransactionDraft? saved;
      await pumpForm(tester, (draft) => saved = draft);

      await tester.enterText(
        find.widgetWithText(TextField, 'Estabelecimento'),
        'PADARIA',
      );
      await tester.enterText(find.widgetWithText(TextField, 'Valor'), '24,80');
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alimentação').last);
      await tester.pumpAndSettle();

      final save = find.text('Salvar transação');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(saved, isNotNull);
      expect(saved!.receiptPath, isNull);
    });

    testWidgets('the receipt field is part of the form', (tester) async {
      await pumpForm(tester, (_) {});

      final field = find.byType(ReceiptField);
      await tester.ensureVisible(field);
      await tester.pumpAndSettle();

      expect(field, findsOneWidget);
      expect(find.text('Comprovante'), findsOneWidget);
    });
  });
}
