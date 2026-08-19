import 'package:financeiro_ai/application/appearance.dart';
import 'package:financeiro_ai/application/providers.dart';
import 'package:financeiro_ai/core/theme.dart';
import 'package:financeiro_ai/core/url_strategy.dart';
import 'package:financeiro_ai/data/demo_finance_repository.dart';
import 'package:financeiro_ai/data/supabase_finance_repository.dart';
import 'package:financeiro_ai/presentation/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  useCleanUrls();
  await initializeDateFormatting('pt_BR');
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  const useSupabase = bool.fromEnvironment('USE_SUPABASE');

  FinanceRepository repository = DemoFinanceRepository();
  if (useSupabase && supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseAnonKey,
    );
    repository = SupabaseFinanceRepository(Supabase.instance.client);
  }

  runApp(
    ProviderScope(
      overrides: [financeRepositoryProvider.overrideWithValue(repository)],
      child: FinanceiroApp(useSupabase: useSupabase),
    ),
  );
}

class FinanceiroApp extends ConsumerStatefulWidget {
  const FinanceiroApp({required this.useSupabase, super.key});

  final bool useSupabase;

  @override
  ConsumerState<FinanceiroApp> createState() => _FinanceiroAppState();
}

class _FinanceiroAppState extends ConsumerState<FinanceiroApp> {
  late final GoRouter _router = buildRouter(useSupabase: widget.useSupabase);

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'Finora',
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(),
    darkTheme: buildAppTheme(brightness: Brightness.dark),
    themeMode: ref.watch(appearanceProvider),
    routerConfig: _router,
  );
}
