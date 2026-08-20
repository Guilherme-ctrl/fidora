import 'package:financeiro_ai/application/providers.dart';
import 'package:financeiro_ai/core/theme.dart';
import 'package:financeiro_ai/domain/shortcut_token.dart';
import 'package:financeiro_ai/presentation/widgets/common.dart';
import 'package:financeiro_ai/core/errors/failure.dart';
import 'package:financeiro_ai/presentation/failure_copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ShortcutTokensPage extends ConsumerWidget {
  const ShortcutTokensPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(shortcutTokensProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Tokens do Atalho')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Novo token'),
      ),
      body: RefreshIndicator(
        onRefresh: () => refreshShortcutTokens(ref),
        child: tokens.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _Message(
            icon: Icons.cloud_off_rounded,
            color: context.palette.negative,
            title: 'Não foi possível carregar os tokens',
            body: 'Verifique sua conexão e tente novamente.',
            onRetry: () => ref.invalidate(shortcutTokensProvider),
          ),
          data: (items) => items.isEmpty
              ? _Message(
                  icon: Icons.key_rounded,
                  color: context.palette.accent,
                  title: 'Nenhum token ainda',
                  body:
                      'O Atalho do iOS usa um token para enviar suas compras. '
                      'Gere um aqui e cole no Atalho — ele aparece uma única vez.',
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 96),
                  itemCount: items.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          'Revogue um token se o aparelho for perdido. A revogação '
                          'vale na próxima captura, e não apaga o que já foi enviado.',
                          style: TextStyle(color: context.palette.inkMuted),
                        ),
                      );
                    }
                    return _TokenTile(
                      token: items[index - 1],
                      onRevoke: () => _revoke(context, ref, items[index - 1]),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: 'iPhone');
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Novo token'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nome',
            helperText: 'Para você reconhecer o aparelho depois.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Gerar'),
          ),
        ],
      ),
    );
    if (name == null || !context.mounted) return;

    try {
      final issued = await ref
          .read(financeRepositoryProvider)
          .createShortcutToken(name);
      await refreshShortcutTokens(ref);
      if (context.mounted) await _showSecret(context, issued);
    } on Failure catch (failure) {
      if (context.mounted) _toast(context, FailureCopy.of(failure).short, error: true);
    }
  }

  /// The one moment the secret exists outside the Shortcut. It is deliberately
  /// not stored, not logged and not recoverable: a lost token is reissued.
  Future<void> _showSecret(BuildContext context, IssuedShortcutToken issued) =>
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Copie agora'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Este token não será mostrado de novo. Cole no campo '
                '“x-shortcut-token” do seu Atalho.',
                style: TextStyle(color: context.palette.inkMuted),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.palette.canvas,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.palette.rule),
                ),
                child: SelectableText(
                  issued.secret,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fechar'),
            ),
            FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: issued.secret));
                if (context.mounted) {
                  Navigator.of(context).pop();
                  _toast(context, 'Token copiado.');
                }
              },
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Copiar'),
            ),
          ],
        ),
      );

  Future<void> _revoke(
    BuildContext context,
    WidgetRef ref,
    ShortcutToken token,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revogar token?'),
        content: Text(
          '“${token.name}” deixará de funcionar na próxima captura. '
          'As transações já enviadas por ele continuam no histórico.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.palette.negative,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Revogar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(financeRepositoryProvider).revokeShortcutToken(token.id);
      await refreshShortcutTokens(ref);
      if (context.mounted) _toast(context, 'Token revogado.');
    } on Failure catch (failure) {
      if (context.mounted) _toast(context, FailureCopy.of(failure).short, error: true);
    }
  }

  void _toast(BuildContext context, String message, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error
              ? context.palette.negative
              : context.palette.income,
        ),
      );
}

class _TokenTile extends StatelessWidget {
  const _TokenTile({required this.token, required this.onRevoke});
  final ShortcutToken token;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        token.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15.5,
                        ),
                      ),
                    ),
                    if (!token.isActive) ...[
                      const SizedBox(width: 8),
                      Chip(
                        label: const Text(
                          'Revogado',
                          style: TextStyle(fontSize: 11),
                        ),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: context.palette.negative.withValues(
                          alpha: .14,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  // Never used is worth saying plainly: it usually means the
                  // Shortcut was never wired up with this one.
                  token.everUsed
                      ? 'Último uso em ${longDate.format(token.lastUsedAt!)}'
                      : 'Nunca usado • criado em ${longDate.format(token.createdAt)}',
                  style: TextStyle(
                    color: context.palette.inkMuted,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          if (token.isActive)
            IconButton(
              tooltip: 'Revogar',
              onPressed: onRevoke,
              icon: Icon(Icons.block_rounded, color: context.palette.negative),
            ),
        ],
      ),
    ),
  );
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    this.onRetry,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(28, 80, 28, 24),
    children: [
      Icon(icon, size: 50, color: color),
      const SizedBox(height: 18),
      Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 19),
      ),
      const SizedBox(height: 8),
      Text(
        body,
        textAlign: TextAlign.center,
        style: TextStyle(color: context.palette.inkMuted, height: 1.45),
      ),
      if (onRetry != null) ...[
        const SizedBox(height: 18),
        Center(
          child: FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar novamente'),
          ),
        ),
      ],
    ],
  );
}
