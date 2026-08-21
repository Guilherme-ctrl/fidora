import 'package:clock/clock.dart';
import 'package:financeiro_ai/features/settings/presenter/cubits/appearance_cubit.dart';
import 'package:financeiro_ai/features/reminders/infra/reminder_service.dart';
import 'package:financeiro_ai/core/theme/breakpoints.dart';
import 'package:financeiro_ai/core/theme/theme.dart';
import 'package:financeiro_ai/core/theme/tokens.dart';
import 'package:financeiro_ai/core/theme/typography.dart';
import 'package:financeiro_ai/features/overview/domain/analytics.dart';
import 'package:financeiro_ai/features/shared/widgets/failure_copy.dart';
import 'package:financeiro_ai/features/ledger/domain/entities/models.dart';
import 'package:financeiro_ai/features/transactions/domain/transaction_filter.dart';
import 'package:financeiro_ai/features/invoices/presenter/pages/cards_page.dart';
import 'package:financeiro_ai/features/catalog/presenter/pages/categories_page.dart';
import 'package:financeiro_ai/features/overview/presenter/pages/dashboard_page.dart';
import 'package:financeiro_ai/features/settings/presenter/pages/more_page.dart';
import 'package:financeiro_ai/features/invoices/presenter/pages/projection_page.dart';
import 'package:financeiro_ai/features/overview/presenter/pages/today_page.dart';
import 'package:financeiro_ai/features/transactions/presenter/pages/transactions_page.dart';
import 'package:financeiro_ai/core/routing/router.dart';
import 'package:financeiro_ai/core/routing/routes.dart';
import 'package:financeiro_ai/core/design_system/common.dart';
import 'package:financeiro_ai/core/design_system/navigation.dart';
import 'package:financeiro_ai/features/transactions/presenter/widgets/transaction_form_sheet.dart';
import 'package:financeiro_ai/features/shared/widgets/command_palette.dart';
import 'package:flutter/services.dart';
import 'package:financeiro_ai/core/design_system/ledger.dart';
import 'package:financeiro_ai/features/ledger/presenter/cubits/finance_cubit.dart';
import 'package:financeiro_ai/features/ledger/presenter/states/finance_state.dart';
import 'package:financeiro_ai/core/design_system/loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// The shell, driven by the address bar.
///
/// It used to own `int index` and a `FinancePeriod` in its own state, which is
/// why F5 returned to tab zero and threw the selected month away. Both now come
/// from the route, and every navigation writes them back into it.
class AppShell extends StatefulWidget {
  const AppShell({
    this.index = 0,
    this.period,
    this.filter = const TransactionFilter(),
    this.openTransactionId,
    this.onSignOut,
    super.key,
  });

  final int index;

  /// Null means the address carried no period, so the current month is used.
  final FinancePeriod? period;

  final TransactionFilter filter;

  /// A transaction addressed directly, at `/transacoes/:id`.
  final String? openTransactionId;

  final Future<void> Function()? onSignOut;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  String? _opened;

  FinancePeriod get period => widget.period ?? FinancePeriod.month(clock.now());

  /// The destinations a phone shows, as indices into [destinations]. Categorias
  /// and Projeção live behind "Mais" there and are first-class on the desktop —
  /// the previous shell handed both surfaces the same five, which is why "Mais"
  /// survived onto a monitor.
  static const _phone = [0, 1, 2, 6];

  /// Rescheduling on every fresh snapshot is what keeps a paid or re-dated
  /// invoice from still buzzing: the reminders screen only runs when someone
  /// opens it, and paying a fatura happens somewhere else entirely.
  Future<void> _syncReminders(FinanceSnapshot snapshot) async {
    final service = context.read<ReminderService>();
    if (!ReminderService.isSupported) return;
    final settings = await service.loadSettings();
    if (!settings.enabled) return;
    await service.sync(snapshot, settings, money: currency.format);
  }

  void _goTo(int index, {FinancePeriod? period, TransactionFilter? filter}) {
    final path = Routes.inOrder[index];
    final active = filter ?? widget.filter;
    context.go(
      locationFor(
        path,
        period: period ?? this.period,
        extra: path == Routes.transactions
            ? FilterCodec.encode(active)
            : const {},
      ),
    );
  }

  List<Command> _commands(FinanceSnapshot? snapshot) => [
    for (var i = 0; i < destinations.length; i++)
      Command(
        label: 'Ir para ${destinations[i].label}',
        group: destinations[i].space.label,
        icon: destinations[i].icon,
        hint: i < 4 ? '${i + 1}' : null,
        run: () => _goTo(i),
      ),
    if (snapshot != null)
      Command(
        label: 'Novo lançamento',
        group: 'Ação',
        icon: Icons.add_rounded,
        hint: 'N',
        run: () => createTransaction(context, snapshot),
      ),
    Command(
      label: 'Recarregar os dados',
      group: 'Ação',
      icon: Icons.refresh_rounded,
      run: () => context.read<FinanceCubit>().reloadAll(),
    ),
    Command(
      label: 'Alternar o tema',
      group: 'Ajustes',
      icon: Icons.brightness_6_rounded,
      run: () {
        final mode = context.read<AppearanceCubit>().state;
        context.read<AppearanceCubit>().set(mode.next);
      },
    ),
  ];

  List<Destination> _withBadge(int pending) => [
    for (final item in destinations)
      item.space == NavSpace.today ? item.withBadge(pending) : item,
  ];

  /// Opens the transaction the address named, once, and puts the address back
  /// when the sheet closes.
  void _maybeOpenAddressed(FinanceSnapshot snapshot) {
    final id = widget.openTransactionId;
    if (id == null || id == _opened) return;
    _opened = id;
    final match = snapshot.transactions
        .where((item) => item.id == id)
        .firstOrNull;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (match == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Esse lançamento não existe mais.')),
        );
      } else {
        await showDetailSheet(
          context,
          title: match.merchant,
          description: 'Lançamento aberto pelo endereço.',
          child: Column(
            children: [
              DetailValue(label: 'Data', value: longDate.format(match.date)),
              DetailValue(label: 'Categoria', value: match.category),
              DetailValue(label: 'Valor', value: currency.format(match.amount)),
              DetailValue(
                label: 'Cartão',
                value: 'final ${match.cardLastFour}',
              ),
            ],
          ),
        );
      }
      if (!mounted) return;
      _opened = null;
      _goTo(2);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<FinanceCubit>().state;
    // Rescheduling on every fresh snapshot is what keeps a paid or re-dated
    // invoice from still buzzing. It was a provider listener; a BlocListener
    // in the tree below does the same and disposes with the widget.
    final layout = Breakpoint.of(context);
    // Keeping the last snapshot on screen while a reload runs is what stops the
    // whole app blanking to a spinner after every write.
    final snapshot = state.snapshot;
    if (snapshot != null) {
      configureCurrency(snapshot.currencyCode);
      _maybeOpenAddressed(snapshot);
    }

    final index = widget.index;
    final items = _withBadge(snapshot?.pendingReviews ?? 0);

    Widget content() => switch ((snapshot, state.hasFailure)) {
      (null, true) => _ErrorState(
        failure: FailureCopy.of(state.failure!),
        onRetry: () => context.read<FinanceCubit>().reloadAll(),
      ),
      // The frame stays. Before this, a phone loading the ledger had no tab
      // bar and no brand — the whole app was a bare column of grey blocks,
      // which reads as broken rather than as busy. Only the content waits.
      (null, false) => Column(
        children: [
          if (layout.isPhone)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 12, 2),
              child: _Brand(compact: true, onSignOut: widget.onSignOut),
            ),
          const Expanded(child: _SnapshotSkeleton()),
        ],
      ),
      (final data?, _) => Column(
        children: [
          if (layout.isPhone)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 12, 2),
              child: _Brand(compact: true, onSignOut: widget.onSignOut),
            ),
          // One period control for the whole app. It used to be repeated
          // inside four pages and missing from a fifth, which quietly
          // ignored the selection.
          if (Routes.isPeriodAware(Routes.inOrder[index]))
            Padding(
              padding: EdgeInsets.fromLTRB(layout.gutter, 8, layout.gutter, 2),
              child: PeriodFilterBar(
                period: period,
                onChanged: (value) => _goTo(index, period: value),
              ),
            ),
          if (state.busy)
            LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: context.palette.rule,
            ),
          if (data.truncated) const _TruncatedLedgerBanner(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => context.read<FinanceCubit>().reloadAll(),
              child: _SelectedPage(
                index: index,
                snapshot: data,
                period: period,
                filter: widget.filter,
                onFilterChanged: (value) => _goTo(2, filter: value),
                onPeriodChanged: (value) => _goTo(index, period: value),
                onOpenInvoices: () => _goTo(4),
              ),
            ),
          ),
        ],
      ),
    };

    // The keyboard is the desktop's interface for a product built around
    // entering and reviewing the same kinds of row. There was not a single
    // `Shortcuts` widget in the codebase before this.
    return BlocListener<FinanceCubit, FinanceState>(
      // Rescheduling on every fresh snapshot is what keeps a paid or re-dated
      // invoice from still buzzing: the reminders screen only runs when someone
      // opens it, and paying a fatura happens somewhere else entirely. This was
      // a provider listener; a BlocListener disposes with the widget.
      listenWhen: (_, after) => after.snapshot != null,
      listener: (_, next) => _syncReminders(next.snapshot!),
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () =>
              showCommandPalette(context, commands: _commands(snapshot)),
          const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
              showCommandPalette(context, commands: _commands(snapshot)),
          if (snapshot != null)
            const SingleActivator(LogicalKeyboardKey.keyN): () =>
                createTransaction(context, snapshot),
          for (var i = 0; i < 4; i++)
            SingleActivator(
              [
                LogicalKeyboardKey.digit1,
                LogicalKeyboardKey.digit2,
                LogicalKeyboardKey.digit3,
                LogicalKeyboardKey.digit4,
              ][i],
            ): () =>
                _goTo(i),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            body: Row(
              children: [
                if (layout.hasRail)
                  LedgerSidebar(
                    items: items,
                    selected: index,
                    compact: !layout.hasSidebar,
                    onSelected: _goTo,
                    // Not `_Brand`: that one is the phone's top bar, with a status
                    // pill and a sign-out button, and it overflowed a 68pt rail by
                    // 200px.
                    header: _SidebarBrand(
                      compact: !layout.hasSidebar,
                      onSearch: () => showCommandPalette(
                        context,
                        commands: _commands(snapshot),
                      ),
                    ),
                    footer: _ShellFooter(
                      compact: !layout.hasSidebar,
                      onSignOut: widget.onSignOut,
                    ),
                  ),
                Expanded(
                  child: SafeArea(
                    // A ledger row loses the eye between merchant and amount long
                    // before a 1920px monitor ends. Content is capped and centred.
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: maxContentWidth,
                        ),
                        child: content(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Shown while loading too: the destinations are known before the
            // ledger is, and a tab bar that disappears during a refresh is a
            // navigation that cannot be trusted.
            bottomNavigationBar: layout.hasRail
                ? null
                : LedgerTabBar(
                    items: [for (final slot in _phone) items[slot]],
                    selected: _phone.indexOf(index),
                    onSelected: (value) => _goTo(_phone[value]),
                    onCreate: snapshot == null
                        ? null
                        : () => createTransaction(context, snapshot),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Theme and sign-out, at the foot of the sidebar.
class _ShellFooter extends StatelessWidget {
  const _ShellFooter({required this.compact, this.onSignOut});
  final bool compact;
  final Future<void> Function()? onSignOut;

  @override
  Widget build(BuildContext context) {
    final mode = context.watch<AppearanceCubit>().state;
    return Row(
      mainAxisAlignment: compact
          ? MainAxisAlignment.center
          : MainAxisAlignment.spaceBetween,
      children: [
        Tooltip(
          message: 'Tema: ${mode.label}',
          child: IconButton(
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            onPressed: () =>
                context.read<AppearanceCubit>().set(mode.next),
            icon: Icon(mode.icon),
          ),
        ),
        if (onSignOut != null && !compact)
          Tooltip(
            message: 'Sair',
            child: IconButton(
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              onPressed: onSignOut,
              icon: const Icon(Icons.logout_rounded),
            ),
          ),
      ],
    );
  }
}

class _SelectedPage extends StatelessWidget {
  const _SelectedPage({
    required this.index,
    required this.snapshot,
    required this.period,
    required this.onPeriodChanged,
    required this.onOpenInvoices,
    required this.filter,
    required this.onFilterChanged,
  });
  final int index;
  final FinanceSnapshot snapshot;
  final FinancePeriod period;
  final ValueChanged<FinancePeriod> onPeriodChanged;
  final VoidCallback onOpenInvoices;
  final TransactionFilter filter;
  final ValueChanged<TransactionFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) => IndexedStack(
    index: index,
    children: [
      TodayPage(
        snapshot: snapshot,
        period: period,
        onOpenInvoices: onOpenInvoices,
      ),
      DashboardPage(
        snapshot: snapshot,
        period: period,
        onPeriodChanged: onPeriodChanged,
      ),
      TransactionsPage(
        snapshot: snapshot,
        period: period,
        onPeriodChanged: onPeriodChanged,
        filter: filter,
        onFilterChanged: onFilterChanged,
      ),
      CategoriesPage(
        snapshot: snapshot,
        period: period,
        onPeriodChanged: onPeriodChanged,
      ),
      CardsPage(snapshot: snapshot, period: period),
      ProjectionPage(
        snapshot: snapshot,
        period: period,
        onPeriodChanged: onPeriodChanged,
      ),
      MorePage(snapshot: snapshot, period: period),
    ],
  );
}

/// The mark alone on a narrow rail, the mark and the name on a full sidebar.
class _SidebarBrand extends StatelessWidget {
  const _SidebarBrand({required this.compact, this.onSearch});
  final bool compact;
  final VoidCallback? onSearch;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final mark = Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: palette.action,
        borderRadius: BorderRadius.circular(Radii.xs),
      ),
      child: Text(
        'F',
        style: context.type.titleMd.copyWith(color: palette.onAction),
      ),
    );
    if (compact) {
      return Column(
        children: [
          mark,
          if (onSearch != null) ...[
            const SizedBox(height: Space.xs),
            IconButton(
              tooltip: 'Buscar ou comandar  ⌘K',
              iconSize: 16,
              visualDensity: VisualDensity.compact,
              onPressed: onSearch,
              icon: const Icon(Icons.search_rounded),
            ),
          ],
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            mark,
            const SizedBox(width: Space.xs),
            Expanded(
              child: Text(
                'Finora',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.type.titleMd,
              ),
            ),
          ],
        ),
        if (onSearch != null) ...[
          const SizedBox(height: Space.sm),
          InkWell(
            onTap: onSearch,
            borderRadius: BorderRadius.circular(Radii.sm),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Space.xs,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                border: Border.all(color: palette.ruleStrong),
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Buscar ou comandar',
                      style: context.type.bodySm.copyWith(
                        color: palette.inkSubtle,
                      ),
                    ),
                  ),
                  const MonoTag('⌘K'),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// The phone's top bar.
///
/// It kept the pre-remake look — a rounded blue square with a chart glyph and
/// "finora" in a heavy lowercase — through every one of the seven PRs, because
/// the sidebar got its own mark in PR 3 and this one was only ever seen on a
/// phone. It is the first thing on the screen there.
class _Brand extends StatelessWidget {
  const _Brand({required this.compact, this.onSignOut});
  final bool compact;
  final Future<void> Function()? onSignOut;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: palette.action,
            borderRadius: BorderRadius.circular(Radii.xs),
          ),
          child: Text(
            'F',
            style: context.type.titleMd.copyWith(color: palette.onAction),
          ),
        ),
        const SizedBox(width: Space.xs),
        Expanded(
          child: Text(
            'Finora',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.type.titleMd,
          ),
        ),
        MonoTag(onSignOut == null ? 'demo' : 'online'),
        if (onSignOut != null) ...[
          const SizedBox(width: Space.xxs),
          IconButton(
            tooltip: 'Sair',
            iconSize: 17,
            visualDensity: VisualDensity.compact,
            onPressed: onSignOut,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.failure, required this.onRetry});
  final FailureCopy failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 48,
            color: context.palette.negative,
          ),
          const SizedBox(height: 16),
          Text(
            failure.message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            failure.hint,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.palette.inkMuted),
          ),
          if (failure.canRetry) ...[
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
          const SizedBox(height: 10),
          // The raw error still matters to whoever has to debug it; it just
          // does not belong in the first thing the person reads.
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              shape: const Border(),
              collapsedShape: const Border(),
              title: Text(
                'Detalhes técnicos',
                style: TextStyle(
                  fontSize: 13,
                  color: context.palette.inkSubtle,
                ),
              ),
              children: [
                SelectableText(
                  failure.detail,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.palette.inkSubtle,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Shown only on the very first load, when there is no previous snapshot to
/// keep on screen. A shape of the dashboard reads as "almost there" in a way a
/// centred spinner does not.
/// The ledger, before it has arrived.
///
/// It used to be static grey blocks that matched nothing on the screen: two
/// squares and two rectangles, in a layout no page actually has. A skeleton
/// that does not match its content is a second layout to maintain, and the
/// page still jumps when the data lands.
///
/// This one is Hoje: a heading with a progress ring beside it, a callout, and
/// the rows of the queue — which is the screen the app opens on.
class _SnapshotSkeleton extends StatelessWidget {
  const _SnapshotSkeleton();

  @override
  Widget build(BuildContext context) => Skeleton(
    child: Semantics(
      label: 'Carregando seus dados',
      excludeSemantics: true,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          Breakpoint.of(context).gutter,
          Space.xl,
          Breakpoint.of(context).gutter,
          Space.xxxl,
        ),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(height: 30, width: 96),
                    SizedBox(height: Space.sm),
                    SkeletonBox.text(width: 232),
                  ],
                ),
              ),
              const SkeletonBox(height: 26, width: 26, radius: Radii.full),
            ],
          ),
          const SizedBox(height: Space.xl),
          const SkeletonBox(height: 84, radius: Radii.md),
          const SizedBox(height: Space.xl),
          const SkeletonBox.text(width: 188),
          const SizedBox(height: Space.md),
          for (var i = 0; i < 4; i++) SkeletonRow(first: i == 0, seed: i),
        ],
      ),
    ),
  );
}

/// Says out loud that the ledger on screen is not all of it.
///
/// The loader used to stop at two thousand rows in silence, which made every
/// total and every average quietly wrong past that point. It now pages through
/// everything, and this exists for the case where a hard ceiling is reached:
/// numbers derived from a partial history must never look like numbers derived
/// from the whole of it.
class _TruncatedLedgerBanner extends StatelessWidget {
  const _TruncatedLedgerBanner();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      color: palette.pending.withValues(alpha: .18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: palette.pending),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Seu histórico passa do que o app carrega de uma vez. Os totais '
              'e comparações desta tela consideram apenas a parte carregada.',
              style: TextStyle(
                color: palette.pending,
                fontSize: 12.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
