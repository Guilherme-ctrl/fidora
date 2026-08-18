import 'package:financeiro_ai/core/theme.dart';
import 'package:financeiro_ai/presentation/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Supabase.instance.client.auth;
    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (auth.currentSession == null) {
          return const AuthPage();
        }
        return AppShell(onSignOut: auth.signOut);
      },
    );
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _createAccount = false;
  bool _loading = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final auth = Supabase.instance.client.auth;
      if (_createAccount) {
        final response = await auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        if (response.session == null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Conta criada. Confirme o e-mail e depois entre no Finora.',
              ),
            ),
          );
          setState(() => _createAccount = false);
        }
      } else {
        await auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        child: Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: moss,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.auto_graph_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        _createAccount ? 'Crie sua conta' : 'Entre no Finora',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Seu controle financeiro, sincronizado no iPhone e na web.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 28),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'E-mail',
                          prefixIcon: Icon(Icons.mail_outline_rounded),
                        ),
                        validator: (value) {
                          final email = value?.trim() ?? '';
                          return email.contains('@')
                              ? null
                              : 'Informe um e-mail válido';
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _hidePassword,
                        autofillHints: const [AutofillHints.password],
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Senha',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _hidePassword = !_hidePassword),
                            icon: Icon(
                              _hidePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (value) => (value?.length ?? 0) >= 8
                            ? null
                            : 'Use pelo menos 8 caracteres',
                      ),
                      const SizedBox(height: 22),
                      FilledButton(
                        onPressed: _loading ? null : _submit,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          child: _loading
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(_createAccount ? 'Criar conta' : 'Entrar'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: _loading
                            ? null
                            : () => setState(
                                () => _createAccount = !_createAccount,
                              ),
                        child: Text(
                          _createAccount
                              ? 'Já tenho uma conta'
                              : 'Criar minha conta',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
