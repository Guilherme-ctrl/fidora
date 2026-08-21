import 'package:financeiro_ai/core/errors/failure.dart';
import 'package:financeiro_ai/core/theme/theme.dart';
import 'package:financeiro_ai/features/auth/domain/repositories/auth_repository.dart';
import 'package:financeiro_ai/features/auth/domain/auth_rules.dart';
import 'package:financeiro_ai/features/shell/presenter/pages/app_shell.dart';
import 'package:financeiro_ai/features/shared/widgets/failure_copy.dart';
import 'package:financeiro_ai/core/design_system/loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({this.child, super.key});

  /// The routed shell. Given by the router so the address bar keeps working
  /// while signed in; the sign-in screen itself does not have an address of its
  /// own yet — that is PR 5, together with account recovery.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthRepository>();
    return StreamBuilder<AuthChange>(
      stream: auth.changes(),
      builder: (context, snapshot) {
        // A recovery link signs the person in; without this branch it would
        // drop them on the dashboard with no way to set a new password.
        if (snapshot.data?.event == AuthEvent.passwordRecovery) {
          return const NewPasswordPage();
        }
        if (auth.currentSession == null) {
          return const AuthPage();
        }
        return child ?? AppShell(onSignOut: auth.signOut);
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
      final auth = context.read<AuthRepository>();
      if (_createAccount) {
        final outcome = await auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        if (outcome == SignUpOutcome.confirmationRequired && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Conta criada. Confirme o e-mail e depois entre no Compasso.',
              ),
            ),
          );
          setState(() => _createAccount = false);
        }
      } else {
        await auth.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }
    } on Failure catch (failure) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(FailureCopy.of(failure).short)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Sends the recovery message. Deliberately answers the same way whether or
  /// not the address has an account, so the screen cannot be used to find out
  /// which e-mails are registered.
  Future<void> _recoverPassword() async {
    final authRepository = context.read<AuthRepository>();
    final email = _emailController.text.trim();
    final problem = validateEmail(email);
    if (problem != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(problem)));
      return;
    }
    setState(() => _loading = true);
    try {
      await authRepository.sendPasswordRecovery(email);
    } on Failure catch (failure) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(FailureCopy.of(failure).short)));
        setState(() => _loading = false);
      }
      return;
    }
    if (mounted) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Se houver uma conta para $email, o link de recuperação chegou por e-mail.',
          ),
        ),
      );
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
                            color: context.palette.accent,
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
                        _createAccount ? 'Crie sua conta' : 'Entre no Compasso',
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
                        validator: (value) => validateEmail(value ?? ''),
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
                        validator: (value) => validatePassword(value ?? ''),
                      ),
                      const SizedBox(height: 22),
                      FilledButton(
                        onPressed: _loading ? null : _submit,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          child: _loading
                              ? const BusySpinner()
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
                      if (!_createAccount)
                        TextButton(
                          onPressed: _loading ? null : _recoverPassword,
                          child: const Text('Esqueci minha senha'),
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

/// Shown when the person arrives through a recovery link. The recovery event
/// has already signed them in at this point, so the only thing missing is the
/// new password.
class NewPasswordPage extends StatefulWidget {
  const NewPasswordPage({super.key});
  @override
  State<NewPasswordPage> createState() => _NewPasswordPageState();
}

class _NewPasswordPageState extends State<NewPasswordPage> {
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _loading = false;
  bool _hide = true;
  AuthFieldErrors _errors = const AuthFieldErrors();

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final authRepository = context.read<AuthRepository>();
    final errors = validateNewPassword(_password.text, _confirmation.text);
    setState(() => _errors = errors);
    if (!errors.isEmpty) return;

    setState(() => _loading = true);
    try {
      await authRepository.updatePassword(_password.text);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Senha atualizada.')));
      }
    } on Failure catch (failure) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(FailureCopy.of(failure).short)));
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Defina uma nova senha',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Você chegou por um link de recuperação. Escolha a senha '
                      'que passará a valer a partir de agora.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.palette.inkMuted),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _password,
                      obscureText: _hide,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: InputDecoration(
                        labelText: 'Nova senha',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        errorText: _errors.password,
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _hide = !_hide),
                          icon: Icon(
                            _hide
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _confirmation,
                      obscureText: _hide,
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Repita a nova senha',
                        prefixIcon: const Icon(Icons.lock_reset_rounded),
                        errorText: _errors.confirmation,
                      ),
                    ),
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        child: _loading
                            ? const BusySpinner()
                            : const Text('Salvar senha'),
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
  );
}
