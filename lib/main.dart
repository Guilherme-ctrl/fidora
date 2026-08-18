import 'package:financeiro_ai/application/providers.dart';
import 'package:financeiro_ai/core/theme.dart';
import 'package:financeiro_ai/data/demo_finance_repository.dart';
import 'package:financeiro_ai/data/supabase_finance_repository.dart';
import 'package:financeiro_ai/presentation/app_shell.dart';
import 'package:financeiro_ai/presentation/auth_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

class FinanceiroApp extends StatelessWidget {
  const FinanceiroApp({required this.useSupabase, super.key});

  final bool useSupabase;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Finora',
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(),
    home: useSupabase ? const AuthGate() : const AppShell(),
  );
}
