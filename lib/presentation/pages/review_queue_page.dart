import 'package:financeiro_ai/application/providers.dart';
import 'package:financeiro_ai/core/theme.dart';
import 'package:financeiro_ai/domain/models.dart';
import 'package:financeiro_ai/domain/review_item.dart';
import 'package:financeiro_ai/domain/transaction_draft.dart';
import 'package:financeiro_ai/presentation/widgets/common.dart';
import 'package:financeiro_ai/presentation/widgets/transaction_form_sheet.dart';
import 'package:financeiro_ai/core/breakpoints.dart';
import 'package:financeiro_ai/core/tokens.dart';
import 'package:financeiro_ai/core/typography.dart';
import 'package:financeiro_ai/presentation/widgets/ledger.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The daily ritual.
///
/// Every item here asks one question and teaches one rule. On a desktop it is
/// driven from the keyboard, because clearing a queue with a mouse is ten
/// round-trips to the same three buttons; on a phone it is driven by swiping,
/// because that is the gesture a queue asks for. Neither existed: there was no
/// `Shortcuts` widget anywhere in the product, and not one `Dismissible`.
class ReviewQueuePage extends ConsumerStatefulWidget {
  const ReviewQueuePage({super.key});

  @override
  ConsumerState<ReviewQueuePage> createState() => _ReviewQueuePageState();
}

class _ReviewQueuePageState extends ConsumerState<ReviewQueuePage> {
  int _cursor = 0;
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _move(int delta, int length) {
    if (length == 0) return;
    setState(() => _cursor = (_cursor + delta).clamp(0, length - 1));
  }

  Future<void> _settle(ReviewItem item, String status) async {
    try {
      await ref
          .read(financeRepositoryProvider)
          .settleReview(item.id, status: status);
      await refreshReviewQueue(ref);
      ref.invalidate(financeSnapshotProvider);
    } on FinanceWriteException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(reviewQueueProvider);
    final items = queue.value ?? const <ReviewItem>[];
    if (_cursor >= items.length && items.isNotEmpty) _cursor = items.length - 1;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyJ): () =>
            _move(1, items.length),
        const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
            _move(1, items.length),
        const SingleActivator(LogicalKeyboardKey.keyK): () =>
            _move(-1, items.length),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
            _move(-1, items.length),
        const SingleActivator(LogicalKeyboardKey.enter): () {
          if (items.isNotEmpty) _settle(items[_cursor], 'resolved');
        },
        const SingleActivator(LogicalKeyboardKey.keyD): () {
          if (items.isNotEmpty) _settle(items[_cursor], 'dismissed');
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Revisões pendentes'),
            actions: [
              if (Breakpoint.of(context).hasRail)
                Padding(
                  padding: const EdgeInsets.only(right: Space.md),
                  child: Row(
                    children: const [
                      MonoTag('J K navegar'),
                      SizedBox(width: Space.xxs),
                      MonoTag('⏎ está certo'),
                      SizedBox(width: Space.xxs),
                      MonoTag('D descartar'),
                    ],
                  ),
                ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () => refreshReviewQueue(ref),
            child: queue.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _QueueError(
                onRetry: () => ref.invalidate(reviewQueueProvider),
              ),
              data: (items) => items.isEmpty
                  ? const _QueueEmpty()
                  : ListView.builder(
                      controller: _scroll,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
                      itemCount: items.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 18),
                            child: Text(
                              '${items.length} ${items.length == 1 ? 'item aguarda' : 'itens aguardam'} sua decisão.',
                              style: TextStyle(color: context.palette.inkMuted),
                            ),
                          );
                        }
                        final item = items[index - 1];
                        final card = _ReviewCard(
                          item: item,
                          focused: index - 1 == _cursor,
                        );
                        // Swipe is the gesture a queue asks for, and the
                        // product had no `Dismissible` at all.
                        return Dismissible(
                          key: ValueKey(item.id),
                          background: _SwipeHint(
                            label: 'Está certo',
                            icon: Icons.check_rounded,
                            color: context.palette.income,
                            alignment: Alignment.centerLeft,
                          ),
                          secondaryBackground: _SwipeHint(
                            label: 'Descartar',
                            icon: Icons.close_rounded,
                            color: context.palette.inkSubtle,
                            alignment: Alignment.centerRight,
                          ),
                          onDismissed: (direction) => _settle(
                            item,
                            direction == DismissDirection.startToEnd
                                ? 'resolved'
                                : 'dismissed',
                          ),
                          child: card,
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// What a swipe is about to do.
class _SwipeHint extends StatelessWidget {
  const _SwipeHint({
    required this.label,
    required this.icon,
    required this.color,
    required this.alignment,
  });
  final String label;
  final IconData icon;
  final Color color;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.symmetric(horizontal: Space.lg),
    alignment: alignment,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(Radii.md),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: context.palette.canvas),
        const SizedBox(width: Space.xs),
        Text(
          label,
          style: context.type.bodySm.copyWith(
            color: context.palette.canvas,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _ReviewCard extends ConsumerWidget {
  const _ReviewCard({required this.item, this.focused = false});
  final ReviewItem item;

  /// The item the keyboard is on.
  final bool focused;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(financeSnapshotProvider).value;
    final transaction = snapshot?.transactions
        .where((row) => row.id == item.transactionId)
        .firstOrNull;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        side: BorderSide(
          color: focused ? context.palette.accent : context.palette.rule,
          width: focused ? Strokes.heavy : Strokes.hairline,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: context.palette.pending.withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.rule_folder_rounded,
                    color: Color(0xFF8D6414),
                    size: 19,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    item.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (transaction != null)
                  Text(
                    currency.format(transaction.amount),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              item.reason,
              style: TextStyle(color: context.palette.inkMuted),
            ),
            if (item.suggestedAction != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 15,
                    color: context.palette.accent,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      item.suggestedAction!,
                      style: TextStyle(
                        color: context.palette.accent,
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (transaction != null) ...[
              const SizedBox(height: 10),
              Text(
                '${longDate.format(transaction.date)} • ${transaction.category} • final ${transaction.cardLastFour}',
                style: TextStyle(color: context.palette.inkMuted, fontSize: 13),
              ),
            ],
            if (item.transactionId != null && transaction == null) ...[
              const SizedBox(height: 10),
              Text(
                'A transação ligada a este item não está no período carregado.',
                style: TextStyle(color: context.palette.inkMuted, fontSize: 13),
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (transaction != null && snapshot != null)
                  FilledButton.icon(
                    onPressed: () =>
                        _correct(context, ref, snapshot, transaction),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Corrigir'),
                  ),
                OutlinedButton.icon(
                  onPressed: () => _settle(context, ref, 'resolved'),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Está certo'),
                ),
                TextButton(
                  onPressed: () => _settle(context, ref, 'dismissed'),
                  child: const Text('Descartar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Correcting and resolving are one gesture: if the edit is saved, the entry
  /// that asked for it has been answered.
  Future<void> _correct(
    BuildContext context,
    WidgetRef ref,
    FinanceSnapshot snapshot,
    FinanceTransaction transaction,
  ) async {
    final saved = await showTransactionFormSheet(
      context,
      snapshot: snapshot,
      existing: transaction,
      onSave: (draft) async {
        await ref.read(financeRepositoryProvider).saveTransaction(draft);
        await ref
            .read(financeRepositoryProvider)
            .settleReview(item.id, status: 'resolved');
        await refreshLedger(ref);
        await refreshReviewQueue(ref);
      },
    );
    if (saved == true && context.mounted) {
      _toast(context, 'Corrigido e revisão concluída.');
    }
  }

  Future<void> _settle(
    BuildContext context,
    WidgetRef ref,
    String status,
  ) async {
    try {
      await ref
          .read(financeRepositoryProvider)
          .settleReview(item.id, status: status);
      await refreshReviewQueue(ref);
      ref.invalidate(financeSnapshotProvider);
      if (context.mounted) {
        _toast(
          context,
          status == 'resolved' ? 'Revisão concluída.' : 'Revisão descartada.',
        );
      }
    } on FinanceWriteException catch (error) {
      if (context.mounted) _toast(context, error.message, error: true);
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

class _QueueEmpty extends StatelessWidget {
  const _QueueEmpty();
  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
    children: [
      Icon(Icons.task_alt_rounded, size: 52, color: context.palette.accent),
      const SizedBox(height: 18),
      const Text(
        'Nada para revisar',
        textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19),
      ),
      const SizedBox(height: 8),
      Text(
        'Quando uma importação ou uma captura do Atalho ficar em dúvida sobre a categoria, o item aparece aqui.',
        textAlign: TextAlign.center,
        style: TextStyle(color: context.palette.inkMuted),
      ),
    ],
  );
}

class _QueueError extends StatelessWidget {
  const _QueueError({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
    children: [
      Icon(Icons.cloud_off_rounded, size: 48, color: context.palette.negative),
      const SizedBox(height: 16),
      const Text(
        'Não foi possível carregar a fila',
        textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
      ),
      const SizedBox(height: 8),
      Text(
        'Verifique sua conexão e tente novamente.',
        textAlign: TextAlign.center,
        style: TextStyle(color: context.palette.inkMuted),
      ),
      const SizedBox(height: 18),
      Center(
        child: FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Tentar novamente'),
        ),
      ),
    ],
  );
}
