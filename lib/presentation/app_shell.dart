import 'package:clock/clock.dart';
import 'package:financeiro_ai/application/appearance.dart';
import 'package:financeiro_ai/application/providers.dart';
import 'package:financeiro_ai/application/reminder_service.dart';
import 'package:financeiro_ai/core/breakpoints.dart';
import 'package:financeiro_ai/core/theme.dart';
import 'package:financeiro_ai/core/tokens.dart';
import 'package:financeiro_ai/core/typography.dart';
import 'package:financeiro_ai/domain/analytics.dart';
import 'package:financeiro_ai/domain/load_failure.dart';
import 'package:financeiro_ai/domain/models.dart';
import 'package:financeiro_ai/domain/transaction_filter.dart';
import 'package:financeiro_ai/presentation/pages/cards_page.dart';
import 'package:financeiro_ai/presentation/pages/categories_page.dart';
import 'package:financeiro_ai/presentation/pages/dashboard_page.dart';
import 'package:financeiro_ai/presentation/pages/more_page.dart';
import 'package:financeiro_ai/presentation/pages/projection_page.dart';
import 'package:financeiro_ai/presentation/pages/today_page.dart';
import 'package:financeiro_ai/presentation/pages/transactions_page.dart';
import 'package:financeiro_ai/presentation/router.dart';
import 'package:financeiro_ai/presentation/routes.dart';
import 'package:financeiro_ai/presentation/widgets/common.dart';
import 'package:financeiro_ai/presentation/widgets/navigation.dart';
import 'package:financeiro_ai/presentation/widgets/transaction_form_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The shell, driven by the address bar.
///
/// It used to own `int index` and a `FinancePeriod` in its own state, which is
/// why F5 returned to tab zero and threw the selected month away. Both now come
/// from the route, and every navigation writes them back into it.
class AppShell extends ConsumerStatefulWidget {
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
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
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
    final service = ref.read(reminderServiceProvider);
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
    ref.listen(financeSnapshotProvider, (_, next) {
      final data = next.value;
      if (data != null) _syncReminders(data);
    });
    final state = ref.watch(financeSnapshotProvider);
    final layout = Breakpoint.of(context);
    // Keeping the last snapshot on screen while a reload runs is what stops the
    // whole app blanking to a spinner after every write.
    final snapshot = state.value;
    if (snapshot != null) {
      configureCurrency(snapshot.currencyCode);
      _maybeOpenAddressed(snapshot);
    }

    final index = widget.index;
    final items = _withBadge(snapshot?.pendingReviews ?? 0);

    Widget content() => switch ((snapshot, state.hasError)) {
      (null, true) => _ErrorState(
        failure: LoadFailure.from(state.error!),
        onRetry: () => ref.invalidate(financeSnapshotProvider),
      ),
      (null, false) => const _SnapshotSkeleton(),
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
          if (state.isLoading)
            LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: context.palette.rule,
            ),
          if (data.truncated) const _TruncatedLedgerBanner(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => refreshFinanceSnapshot(ref),
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

    return Scaffold(
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
              header: _SidebarBrand(compact: !layout.hasSidebar),
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
                  constraints: const BoxConstraints(maxWidth: maxContentWidth),
                  child: content(),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: layout.hasRail || snapshot == null
          ? null
          : LedgerTabBar(
              items: [for (final slot in _phone) items[slot]],
              selected: _phone.indexOf(index),
              onSelected: (value) => _goTo(_phone[value]),
              onCreate: () => createTransaction(context, ref, snapshot),
            ),
    );
  }
}

/// Theme and sign-out, at the foot of the sidebar.
class _ShellFooter extends ConsumerWidget {
  const _ShellFooter({required this.compact, this.onSignOut});
  final bool compact;
  final Future<void> Function()? onSignOut;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(appearanceProvider);
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
                ref.read(appearanceProvider.notifier).set(mode.next),
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
  const _SidebarBrand({required this.compact});
  final bool compact;

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
    if (compact) return Center(child: mark);
    return Row(
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
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.compact, this.onSignOut});
  final bool compact;
  final Future<void> Function()? onSignOut;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: context.palette.brand,
          borderRadius: BorderRadius.circular(13),
        ),
        child: const Icon(Icons.auto_graph_rounded, color: Colors.white),
      ),
      if (!compact || MediaQuery.sizeOf(context).width > 360) ...[
        const SizedBox(width: 10),
        Text(
          'finora',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -1,
          ),
        ),
      ],
      if (compact) const Spacer(),
      if (compact)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: context.palette.brandSoft,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            onSignOut == null ? 'Demo' : 'Online',
            style: TextStyle(
              color: context.palette.brand,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      if (compact && onSignOut != null) ...[
        const SizedBox(width: 4),
        IconButton(
          tooltip: 'Sair',
          onPressed: onSignOut,
          icon: const Icon(Icons.logout_rounded),
        ),
      ],
    ],
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.failure, required this.onRetry});
  final LoadFailure failure;
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
            color: context.palette.danger,
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
class _SnapshotSkeleton extends StatelessWidget {
  const _SnapshotSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget block(double height, {double width = double.infinity}) => Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: context.palette.hairline,
        borderRadius: BorderRadius.circular(14),
      ),
    );

    return Semantics(
      label: 'Carregando seus dados',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 28, 18, 36),
        children: [
          block(28, width: 220),
          const SizedBox(height: 12),
          block(16, width: 150),
          const SizedBox(height: 26),
          Row(
            children: [
              Expanded(child: block(96)),
              const SizedBox(width: 14),
              Expanded(child: block(96)),
            ],
          ),
          const SizedBox(height: 14),
          block(210),
          const SizedBox(height: 14),
          block(150),
        ],
      ),
    );
  }
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
      color: palette.warning.withValues(alpha: .18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: palette.onWarning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Seu histórico passa do que o app carrega de uma vez. Os totais '
              'e comparações desta tela consideram apenas a parte carregada.',
              style: TextStyle(
                color: palette.onWarning,
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
