import 'package:financeiro_ai/features/transactions/infra/receipt_recognizer.dart';
import 'package:financeiro_ai/features/reminders/infra/reminder_service.dart';
import 'package:financeiro_ai/core/di/dependencies.dart';
import 'package:financeiro_ai/core/platform/file_access.dart';
import 'package:financeiro_ai/features/ledger/infra/repositories/demo_finance_repository.dart';
import 'package:financeiro_ai/features/auth/infra/repositories/fake_auth_repository.dart';
import 'package:financeiro_ai/features/auth/domain/repositories/auth_repository.dart';
import 'package:financeiro_ai/features/ledger/domain/repositories/repositories.dart';
import 'package:flutter/widgets.dart';

/// The composition root, with test-shaped defaults.
///
/// `Dependencies` itself stays strict — a production build that forgot to pass
/// a repository should not silently run on the demo one. This supplies the
/// defaults a widget test wants, and nothing else changes.
Widget withDependencies({
  required Widget child,
  FinanceRepository? repository,
  AuthRepository? auth,
  ReceiptRecognizer? recognizer,
  ReminderService? reminders,
  FilePicker? filePicker,
  ImageCapture? imageCapture,
  ShareService? shareService,
}) => Dependencies(
  repository: repository ?? DemoFinanceRepository(),
  // Signed in by default: almost every test is about a screen behind the gate,
  // and the gate has its own file.
  auth:
      auth ??
      FakeAuthRepository(
        session: const AuthSession(userId: 'u1', email: 'quem@exemplo.com'),
      ),
  recognizer: recognizer ?? const UnavailableReceiptRecognizer(),
  reminders: reminders,
  filePicker: filePicker,
  imageCapture: imageCapture,
  shareService: shareService,
  child: child,
);
