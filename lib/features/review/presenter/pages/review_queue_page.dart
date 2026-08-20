import 'package:financeiro_ai/core/theme/theme.dart';
import 'package:financeiro_ai/features/review/domain/merchant_identity.dart';
import 'package:financeiro_ai/features/ledger/domain/entities/models.dart';
import 'package:financeiro_ai/features/review/domain/review_item.dart';
import 'package:financeiro_ai/features/transactions/presenter/widgets/transaction_form_sheet.dart';
import 'package:financeiro_ai/core/theme/breakpoints.dart';
import 'package:financeiro_ai/core/theme/tokens.dart';
import 'package:financeiro_ai/core/theme/typography.dart';
import 'package:financeiro_ai/core/design_system/common.dart';
import 'package:financeiro_ai/core/design_system/ledger.dart';
import 'package:flutter/services.dart';
import 'package:financeiro_ai/core/errors/failure.dart';
import 'package:financeiro_ai/features/shared/widgets/failure_copy.dart';
import 'package:financeiro_ai/features/catalog/presenter/cubits/catalog_cubits.dart';
import 'package:financeiro_ai/features/ledger/presenter/cubits/finance_cubit.dart';
import 'package:financeiro_ai/features/ledger/domain/repositories/repositories.dart';
import 'package:financeiro_ai/core/state/load_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Items that ask the same question about the same place.
///
/// Nine captures from MERCADO EXTRA are not nine decisions, they are one. This
/// is where most of the weight of a 24-item queue actually goes: not motivation,
/// volume.
class _Group {
  _Group({
    required this.label,
    required this.items,
    required this.transactions,
  });

  final String label;
  final List<ReviewItem> items;

  /// Every transaction behind the group, not a sample. The card shows what the
  /// group is worth and when it happened, and one row cannot say either.
  final List<FinanceTransaction> transactions;

  int get size => items.length;
  ReviewItem get first => items.first;
  FinanceTransaction? get sample => transactions.firstOrNull;

  double get total =>
      transactions.fold<double>(0, (sum, row) => sum + row.amount);

  DateTime? get earliest => transactions.isEmpty
      ? null
      : transactions.map((r) => r.date).reduce((a, b) => a.isBefore(b) ? a : b);

  DateTime? get latest => transactions.isEmpty
      ? null
      : transactions.map((r) => r.date).reduce((a, b) => a.isAfter(b) ? a : b);

  /// The categories the group currently sits in. More than one means the shop
  /// has been filed inconsistently, which is worth seeing before deciding.
  Set<String> get categories =>
      transactions.map((r) => r.category).where((c) => c.isNotEmpty).toSet();

  Set<String> get cards => transactions
      .map((r) => r.isCard ? '·${r.cardLastFour}' : 'conta')
      .toSet();

  static List<_Group> from(List<ReviewItem> items, FinanceSnapshot? snapshot) {
    final byKey = <String, List<ReviewItem>>{};
    final rows = <String, List<FinanceTransaction>>{};
    for (final item in items) {
      final transaction = snapshot?.transactions
          .where((row) => row.id == item.transactionId)
          .firstOrNull;
      // Normalised, or the same shop arrives as several groups: the instalment
      // is written inside the name, so `LOJA X 03/10` and `LOJA X 04/10` would
      // never meet.
      final merchant = transaction?.merchant;
      final key = merchant == null ? item.reason : merchantIdentity(merchant);
      byKey.putIfAbsent(key, () => []).add(item);
      rows.putIfAbsent(key, () => []);
      if (transaction != null) rows[key]!.add(transaction);
    }
    return [
      for (final entry in byKey.entries)
        _Group(
          label: entry.key,
          items: entry.value,
          transactions: rows[entry.key] ?? const [],
        ),
    ]..sort((a, b) => b.size.compareTo(a.size));
  }
}

/// The daily ritual.
///
/// The first version of this screen was a scrolling list of every pending item.
/// The owner's reaction to twenty-four of them was that it made him not want to
/// start — which is the right reaction to a wall.
///
/// Three things carry the weight, and none of them is a reward. Items are
/// grouped, so twenty-four become six real decisions. One group is on screen at
/// a time, so the next decision is all that is visible. And progress is shown
/// and moves, so clearing has a direction and an end.
class ReviewQueuePage extends StatefulWidget {
  const ReviewQueuePage({super.key});

  @override
  State<ReviewQueuePage> createState() => _ReviewQueuePageState();
}

class _ReviewQueuePageState extends State<ReviewQueuePage> {
  @override
  void initState() {
    super.initState();
    // The queue was a FutureProvider and fetched on first watch. A cubit does
    // not, so the screen asks — which keeps the fetch off the app's first
    // paint, where it never belonged.
    context.read<ReviewQueueCubit>().loadOnce();
  }

  int _cursor = 0;

  /// How many items this sitting has settled, and how many decisions it took.
  /// The gap between the two is what grouping bought, and it is worth showing.
  int _settled = 0;
  int _decisions = 0;
  int _startedWith = 0;

  /// Which way the card leaves: right for kept, left for dismissed.
  int _exit = 1;
  bool _finished = false;

  Future<void> _settleGroup(_Group group, String status) async {
    final review = context.read<ReviewRepository>();
    final reviewQueue = context.read<ReviewQueueCubit>();
    final finance = context.read<FinanceCubit>();
    setState(() => _exit = status == 'resolved' ? 1 : -1);
    try {
      for (final item in group.items) {
        await review.settleReview(item.id, status: status);
      }
      if (!mounted) return;
      setState(() {
        _settled += group.size;
        _decisions += 1;
        _cursor = 0;
      });
      await reviewQueue.reload();
      finance.reloadAll();
    } on Failure catch (failure) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(FailureCopy.of(failure).short)));
      }
    }
  }

  /// Correcting settles the entry that asked, because a saved edit answers it.
  ///
  /// It used to live inside the card, which meant the progress counter never
  /// moved: a correction resolved the item and the header went on saying the
  /// same number. Answering an item any way at all has to count.
  Future<void> _correct(
    _Group group,
    FinanceTransaction transaction,
    FinanceSnapshot snapshot,
  ) async {
    final transactions = context.read<TransactionRepository>();
    final review = context.read<ReviewRepository>();
    final finance = context.read<FinanceCubit>();
    final reviewQueue = context.read<ReviewQueueCubit>();
    final item = group.items.firstWhere(
      (row) => row.transactionId == transaction.id,
      orElse: () => group.first,
    );
    final saved = await showTransactionFormSheet(
      context,
      snapshot: snapshot,
      existing: transaction,
      onSave: (draft) async {
        await transactions.saveTransaction(draft);
        await review.settleReview(item.id, status: 'resolved');
        await finance.reloadLedger();
        await reviewQueue.reload();
      },
    );
    if (saved != true || !mounted) return;
    setState(() {
      _settled += 1;
      _decisions += 1;
      _exit = 1;
    });
    finance.reloadAll();
  }

  void _move(int delta, int length) {
    if (length == 0) return;
    setState(() => _cursor = (_cursor + delta).clamp(0, length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final queue = context.watch<ReviewQueueCubit>().state;
    final snapshot = context.watch<FinanceCubit>().state.snapshot;
    final items = queue.dataOrNull ?? const <ReviewItem>[];
    final groups = _Group.from(items, snapshot);
    if (_startedWith == 0 && items.isNotEmpty) _startedWith = items.length;
    if (_cursor >= groups.length && groups.isNotEmpty) {
      _cursor = groups.length - 1;
    }
    if (groups.isEmpty && _settled > 0 && !_finished) _finished = true;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyJ): () =>
            _move(1, groups.length),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            _move(1, groups.length),
        const SingleActivator(LogicalKeyboardKey.keyK): () =>
            _move(-1, groups.length),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            _move(-1, groups.length),
        const SingleActivator(LogicalKeyboardKey.enter): () {
          if (groups.isNotEmpty) _settleGroup(groups[_cursor], 'resolved');
        },
        const SingleActivator(LogicalKeyboardKey.keyD): () {
          if (groups.isNotEmpty) _settleGroup(groups[_cursor], 'dismissed');
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(title: const Text('Revisões')),
          body: switch (queue) {
          LoadFailed() => _QueueError(onRetry: () => context.read<ReviewQueueCubit>().reload()),
          LoadSuccess(data: final _) ||
          LoadReloading(previous: final _) => snapshot == null
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      _Progress(
                        settled: _settled,
                        remaining: items.length,
                        total: _startedWith == 0 ? items.length : _startedWith,
                        groups: groups.length,
                      ),
                      Expanded(
                        child: groups.isEmpty
                            ? _QueueDone(
                                settled: _settled,
                                decisions: _decisions,
                                celebrate: _finished,
                              )
                            : _Deck(
                                groups: groups,
                                cursor: _cursor,
                                exit: _exit,
                                onKeep: (g) => _settleGroup(g, 'resolved'),
                                onDismiss: (g) => _settleGroup(g, 'dismissed'),
                                onCorrect: (g, t) => _correct(g, t, snapshot),
                              ),
                      ),
                      if (Breakpoint.of(context).hasRail && groups.isNotEmpty)
                        const Padding(
                          padding: EdgeInsets.only(bottom: Space.lg),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
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
          _ => const Center(child: CircularProgressIndicator()),
        },
        ),
      ),
    );
  }
}

/// How far along, and moving.
///
/// A number that jumps is information; a number that travels is progress.
class _Progress extends StatelessWidget {
  const _Progress({
    required this.settled,
    required this.remaining,
    required this.total,
    required this.groups,
  });

  final int settled;
  final int remaining;
  final int total;

  /// How many decisions are left, which is the number that actually predicts
  /// how long this will take.
  final int groups;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final ratio = total == 0 ? 1.0 : settled / total;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.lg,
        Space.xs,
        Space.lg,
        Space.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Aqui o anel cresce, porque aqui o progresso é o assunto da tela.
              ProgressRing(value: ratio, size: 38, stroke: 4),
              const SizedBox(width: Space.sm),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: settled.toDouble()),
                duration: Motion.count,
                curve: Curves.easeOutCubic,
                builder: (context, value, _) =>
                    Text('${value.round()}', style: context.type.displayMetric),
              ),
              Text(
                ' de $total',
                style: context.type.bodySm.copyWith(color: palette.inkMuted),
              ),
              const Spacer(),
              Text(
                remaining == 0
                    ? 'fila limpa'
                    : groups == remaining
                    ? '$remaining ${remaining == 1 ? 'restante' : 'restantes'}'
                    // Six left, but four decisions: that gap is the point of
                    // grouping and it belongs where someone decides whether to
                    // start.
                    : '$remaining em $groups ${groups == 1 ? 'decisão' : 'decisões'}',
                style: context.type.meta.copyWith(color: palette.inkSubtle),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One group on screen, the rest stacked behind it.
class _Deck extends StatelessWidget {
  const _Deck({
    required this.groups,
    required this.cursor,
    required this.exit,
    required this.onKeep,
    required this.onDismiss,
    required this.onCorrect,
  });

  final List<_Group> groups;
  final int cursor;
  final int exit;
  final ValueChanged<_Group> onKeep;
  final ValueChanged<_Group> onDismiss;
  final void Function(_Group, FinanceTransaction) onCorrect;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final group = groups[cursor];
    final behind = (groups.length - cursor - 1).clamp(0, 2);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.lg),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // The stack behind is the only place the size of the queue is
              // still visible, and it shrinks as the deck does.
              //
              // `Positioned.fill` rather than a fixed height: the Stack takes
              // its size from the card, so the ghosts match it and their edges
              // show below. Given a height of their own they were shorter than
              // the card and vanished behind it entirely.
              for (var depth = behind; depth >= 1; depth--)
                Positioned.fill(
                  child: Transform.translate(
                    offset: Offset(0, depth * 9),
                    child: Transform.scale(
                      scale: 1 - depth * 0.035,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: palette.surface,
                          border: Border.all(color: palette.rule),
                          borderRadius: BorderRadius.circular(Radii.lg),
                          boxShadow: Depth.resting(palette.canvas),
                        ),
                      ),
                    ),
                  ),
                ),
              AnimatedSwitcher(
                duration: Motion.panel,
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  final leaving = child.key != ValueKey(group.label);
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween(
                        begin: leaving
                            ? Offset(exit.toDouble(), 0)
                            : const Offset(0, .12),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: _GroupCard(
                  key: ValueKey(group.label),
                  group: group,
                  onKeep: () => onKeep(group),
                  onDismiss: () => onDismiss(group),
                  onCorrect: (transaction) => onCorrect(group, transaction),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The one decision on screen, with everything known about it.
///
/// The first version showed the merchant, its category and the suggestion, and
/// the owner's reaction after using it was that there was too little to decide
/// on. Deciding whether a charge is filed correctly needs the charge: what it
/// cost, when, on which card, how it was classified and how sure the classifier
/// was. All of it is already in the row.
class _GroupCard extends StatelessWidget {
  const _GroupCard({
    super.key,
    required this.group,
    required this.onKeep,
    required this.onDismiss,
    required this.onCorrect,
  });

  final _Group group;
  final VoidCallback onKeep;
  final VoidCallback onDismiss;
  final void Function(FinanceTransaction) onCorrect;

  static String _origin(String source) => switch (source) {
    'apple_pay' => 'Atalho, no momento da compra',
    'shortcut' => 'Atalho, no momento da compra',
    'manual' => 'Digitado no app',
    'invoice_import' => 'Importação de fatura',
    'statement_import' => 'Importação de extrato',
    'migration' => 'Migração da planilha',
    _ => source,
  };

  static (String, Color) _confidence(BuildContext context, String value) =>
      switch (value) {
        'high' => ('alta', context.palette.income),
        'medium' => ('média', context.palette.pending),
        'low' => ('baixa', context.palette.negative),
        _ => (value, context.palette.inkSubtle),
      };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final type = context.type;
    final sample = group.sample;
    final many = group.size > 1;
    final earliest = group.earliest;
    final latest = group.latest;

    return Dismissible(
      key: ValueKey('swipe-${group.label}'),
      background: _SwipeHint(
        label: 'Está certo',
        icon: Icons.check_rounded,
        color: palette.income,
        alignment: Alignment.centerLeft,
      ),
      secondaryBackground: _SwipeHint(
        label: 'Descartar',
        icon: Icons.close_rounded,
        color: palette.inkSubtle,
        alignment: Alignment.centerRight,
      ),
      onDismissed: (direction) =>
          direction == DismissDirection.startToEnd ? onKeep() : onDismiss(),
      child: Container(
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border.all(color: palette.rule),
          borderRadius: BorderRadius.circular(Radii.lg),
          // O baralho é a única coisa do app que se empilha de verdade, então
          // é a única que ganha sombra de peso.
          boxShadow: Depth.raised(palette.canvas),
        ),
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: SectionLabel(group.first.reason)),
                if (many)
                  MonoTag('${group.size} lançamentos', color: palette.accent),
              ],
            ),
            const SizedBox(height: Space.xs),
            Text(group.label, style: type.titleLg),
            const SizedBox(height: Space.xs),

            // What it cost. For a group this is the sum, which is the number
            // that decides whether it deserves a closer look.
            if (group.transactions.isNotEmpty) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AmountText(
                    group.total,
                    tone: MoneyTone.expense,
                    size: AmountSize.metric,
                    sign: false,
                    align: TextAlign.start,
                  ),
                  const SizedBox(width: Space.xs),
                  if (many)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        'no total',
                        style: type.meta.copyWith(color: palette.inkSubtle),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: Space.sm),
            ],

            _Facts(
              rows: [
                if (earliest != null)
                  (
                    'quando',
                    latest == null || _sameDay(earliest, latest)
                        ? longDate.format(earliest)
                        : '${shortDate.format(earliest)} a ${shortDate.format(latest)}',
                  ),
                if (group.categories.isNotEmpty)
                  (
                    group.categories.length == 1
                        ? 'categoria hoje'
                        : 'categorias hoje',
                    group.categories.join(', '),
                  ),
                if (group.cards.isNotEmpty)
                  (
                    group.cards.length == 1 ? 'cartão' : 'cartões',
                    group.cards.join(', '),
                  ),
                if (sample != null && sample.isInstallment)
                  (
                    'parcela',
                    '${sample.installmentCurrent}/${sample.installmentTotal}',
                  ),
                if (sample != null && sample.rawModality != null)
                  ('modalidade', sample.rawModality!),
                if (sample != null) ('entrou por', _origin(sample.source)),
                if (sample?.sourceFile != null)
                  ('arquivo', sample!.sourceFile!),
                if (sample?.isShared ?? false)
                  ('sua parte', currency.format(sample!.personalShare)),
              ],
            ),

            if (sample?.confidence != null) ...[
              const SizedBox(height: Space.xs),
              Row(
                children: [
                  const Expanded(child: SectionLabel('classificação')),
                  MonoTag(
                    'confiança ${_confidence(context, sample!.confidence!).$1}',
                    color: _confidence(context, sample.confidence!).$2,
                  ),
                ],
              ),
            ],

            if (group.first.suggestedAction != null) ...[
              const SizedBox(height: Space.sm),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(Space.sm),
                decoration: BoxDecoration(
                  color: palette.accentSoft,
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
                child: Text(
                  group.first.suggestedAction!,
                  style: type.bodySm.copyWith(color: palette.accent),
                ),
              ),
            ],

            const SizedBox(height: Space.lg),
            Row(
              children: [
                Expanded(
                  child: InkButton(
                    label: many ? 'Está certo (${group.size})' : 'Está certo',
                    icon: Icons.check_rounded,
                    onPressed: onKeep,
                  ),
                ),
                const SizedBox(width: Space.xs),
                if (sample != null)
                  InkButton(
                    label: 'Corrigir',
                    secondary: true,
                    onPressed: () => onCorrect(sample),
                  ),
              ],
            ),
            if (many && sample != null) ...[
              const SizedBox(height: Space.xxs),
              Text(
                'Corrigir resolve um; os outros ${group.size - 1} continuam na fila.',
                style: type.meta.copyWith(color: palette.inkSubtle),
              ),
            ],
            const SizedBox(height: Space.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onDismiss,
                child: Text(many ? 'Descartar os ${group.size}' : 'Descartar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// A compact label-and-value list. Everything known, without a wall of text.
class _Facts extends StatelessWidget {
  const _Facts({required this.rows});
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final palette = context.palette;
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: palette.rule)),
      ),
      padding: const EdgeInsets.only(top: Space.xs),
      child: Column(
        children: [
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.xxs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 110, child: SectionLabel(label)),
                  Expanded(
                    child: Text(
                      value,
                      style: context.type.bodySm,
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            ),
        ],
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

/// The end of the queue, which used to be an empty screen.
///
/// [celebrate] separates "you cleared it just now" from "there was nothing to
/// do". Only the first is worth a moment.
class _QueueDone extends StatelessWidget {
  const _QueueDone({
    required this.settled,
    required this.decisions,
    required this.celebrate,
  });

  final int settled;
  final int decisions;
  final bool celebrate;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: celebrate ? 0.9 : 1, end: 1),
        duration: Motion.sheet,
        curve: Curves.easeOutBack,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: Padding(
          padding: const EdgeInsets.all(Space.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                celebrate
                    ? Icons.check_circle_outline_rounded
                    : Icons.inbox_rounded,
                size: 44,
                color: celebrate ? palette.income : palette.inkSubtle,
              ),
              const SizedBox(height: Space.md),
              Text(
                celebrate ? 'Fila zerada.' : 'Nada para revisar',
                style: context.type.titleLg,
              ),
              const SizedBox(height: Space.xs),
              Text(
                celebrate
                    // The gap between the two numbers is what grouping bought.
                    ? '$settled ${settled == 1 ? 'lançamento revisado' : 'lançamentos revisados'} em '
                          '$decisions ${decisions == 1 ? 'decisão' : 'decisões'}.'
                    : 'Quando uma importação ou uma captura do Atalho ficar em '
                          'dúvida sobre a categoria, o item aparece aqui.',
                textAlign: TextAlign.center,
                style: context.type.bodySm.copyWith(color: palette.inkMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
