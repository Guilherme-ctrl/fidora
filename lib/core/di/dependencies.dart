import 'package:financeiro_ai/features/transactions/infra/receipt_recognizer.dart';
import 'package:financeiro_ai/features/reminders/infra/reminder_service.dart';
import 'package:financeiro_ai/core/platform/file_access.dart';
import 'package:financeiro_ai/core/platform/platform_services.dart';
import 'package:financeiro_ai/features/auth/domain/repositories/auth_repository.dart';
import 'package:financeiro_ai/features/ledger/domain/repositories/repositories.dart';
import 'package:financeiro_ai/features/settings/presenter/cubits/appearance_cubit.dart';
import 'package:financeiro_ai/features/catalog/presenter/cubits/catalog_cubits.dart';
import 'package:financeiro_ai/features/ledger/presenter/cubits/finance_cubit.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The one place dependencies are composed.
///
/// Everything below this widget reaches its collaborators through
/// `context.read`, and nothing constructs a repository, a plugin or a client
/// for itself. The six data contracts are all satisfied by the same object —
/// see `domain/repositories/repositories.dart` for why they are six.
class Dependencies extends StatelessWidget {
  const Dependencies({
    required this.repository,
    required this.auth,
    required this.child,
    this.recognizer,
    this.reminders,
    this.filePicker,
    this.imageCapture,
    this.shareService,
    super.key,
  });

  final FinanceRepository repository;
  final AuthRepository auth;

  /// Overridable so a test can drive the app without a camera, a file chooser
  /// or a share sheet. Each falls back to the real implementation.
  final ReceiptRecognizer? recognizer;
  final ReminderService? reminders;
  final FilePicker? filePicker;
  final ImageCapture? imageCapture;
  final ShareService? shareService;

  final Widget child;

  @override
  Widget build(BuildContext context) => MultiRepositoryProvider(
    providers: [
      RepositoryProvider<TransactionRepository>.value(value: repository),
      RepositoryProvider<CatalogRepository>.value(value: repository),
      RepositoryProvider<InvoiceRepository>.value(value: repository),
      RepositoryProvider<ReviewRepository>.value(value: repository),
      RepositoryProvider<ShortcutTokenRepository>.value(value: repository),
      RepositoryProvider<ReceiptStorage>.value(value: repository),
      RepositoryProvider<AuthRepository>.value(value: auth),
      RepositoryProvider<ReceiptRecognizer>.value(
        value: recognizer ?? defaultReceiptRecognizer(),
      ),
      RepositoryProvider<ReminderService>.value(
        value: reminders ?? defaultReminderService(),
      ),
      RepositoryProvider<FilePicker>.value(
        value: filePicker ?? const SystemFilePicker(),
      ),
      RepositoryProvider<ImageCapture>.value(
        value: imageCapture ?? const SystemImageCapture(),
      ),
      RepositoryProvider<ShareService>.value(
        value: shareService ?? const SystemShareService(),
      ),
    ],
    child: MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => FinanceCubit(
            catalog: context.read<CatalogRepository>(),
            transactions: context.read<TransactionRepository>(),
          )..load(),
        ),
        BlocProvider(
          // Lazy on purpose: the review queue is loaded when its screen opens,
          // not folded into the first paint.
          create: (context) => ReviewQueueCubit(context.read()),
        ),
        BlocProvider(create: (context) => MerchantRulesCubit(context.read())),
        BlocProvider(create: (context) => ShortcutTokensCubit(context.read())),
        BlocProvider(create: (context) => ImportBatchesCubit(context.read())),
        BlocProvider(create: (_) => AppearanceCubit()),
      ],
      child: child,
    ),
  );
}
