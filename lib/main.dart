import 'package:financeiro_ai/presentation/cubits/appearance_cubit.dart';
import 'package:financeiro_ai/core/di/dependencies.dart';
import 'package:financeiro_ai/core/theme.dart';
import 'package:financeiro_ai/core/url_strategy.dart';
import 'package:financeiro_ai/data/demo_finance_repository.dart';
import 'package:financeiro_ai/data/fake_auth_repository.dart';
import 'package:financeiro_ai/data/supabase_auth_repository.dart';
import 'package:financeiro_ai/data/supabase_finance_repository.dart';
import 'package:financeiro_ai/domain/auth_repository.dart';
import 'package:financeiro_ai/domain/repositories/repositories.dart';
import 'package:financeiro_ai/presentation/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
  AuthRepository auth = FakeAuthRepository();
  if (useSupabase && supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseAnonKey,
    );
    // The client is read once, here, and handed to both repositories. Nothing
    // below this line reaches for `Supabase.instance` — the sign-in screen used
    // to, which is why none of it could be tested.
    final client = Supabase.instance.client;
    repository = SupabaseFinanceRepository(client);
    auth = SupabaseAuthRepository(client);
  }

  runApp(
    Dependencies(
      repository: repository,
      auth: auth,
      child: FinanceiroApp(useSupabase: useSupabase),
    ),
  );
}

class FinanceiroApp extends StatefulWidget {
  const FinanceiroApp({required this.useSupabase, super.key});

  final bool useSupabase;

  @override
  State<FinanceiroApp> createState() => _FinanceiroAppState();
}

class _FinanceiroAppState extends State<FinanceiroApp> {
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
    // O produto é pt-BR desde a fundação e nunca declarou localização, então
    // todo widget do Material caía no inglês padrão — e os seletores de data,
    // que pedem `pt_BR` explicitamente, não encontravam tradução nenhuma e
    // lançavam ao abrir. Era o caso em Projeção, em Metas e no formulário de
    // lançamento, ou seja, em todos.
    locale: const Locale('pt', 'BR'),
    supportedLocales: const [Locale('pt', 'BR'), Locale('en')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: buildAppTheme(),
    darkTheme: buildAppTheme(brightness: Brightness.dark),
    // O escuro é o padrão. O claro continua inteiro e escolhível em Ajustes,
    // mas deixou de ser o rosto do produto: é no escuro que a cor tem energia
    // e é no escuro que este app é aberto à noite.
    themeMode: context.watch<AppearanceCubit>().state,
    routerConfig: _router,
  );
}
