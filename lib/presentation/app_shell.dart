import 'package:clock/clock.dart';
import 'package:financeiro_ai/application/providers.dart';
import 'package:financeiro_ai/application/reminder_service.dart';
import 'package:financeiro_ai/core/theme.dart';
import 'package:financeiro_ai/domain/analytics.dart';
import 'package:financeiro_ai/domain/load_failure.dart';
import 'package:financeiro_ai/domain/models.dart';
import 'package:financeiro_ai/presentation/pages/cards_page.dart';
import 'package:financeiro_ai/presentation/pages/categories_page.dart';
import 'package:financeiro_ai/presentation/pages/dashboard_page.dart';
import 'package:financeiro_ai/presentation/pages/more_page.dart';
import 'package:financeiro_ai/presentation/pages/transactions_page.dart';
import 'package:financeiro_ai/presentation/widgets/common.dart';
import 'package:financeiro_ai/presentation/widgets/transaction_form_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({this.onSignOut, super.key});

  final Future<void> Function()? onSignOut;
  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int index = 0;
  FinancePeriod period = FinancePeriod.month(clock.now());

  /// Five destinations, the Material maximum. Projeção used to be the sixth;
  /// it is derived data consulted occasionally, so it now lives behind "Mais"
  /// instead of crowding the bar on a 360pt screen.
  static const destinations = [
    NavigationDestination(
      icon: Icon(Icons.space_dashboard_outlined),
      selectedIcon: Icon(Icons.space_dashboard_rounded),
      label: 'Visão geral',
    ),
    NavigationDestination(
      icon: Icon(Icons.receipt_long_outlined),
      selectedIcon: Icon(Icons.receipt_long_rounded),
      label: 'Histórico',
    ),
    NavigationDestination(
      icon: Icon(Icons.category_outlined),
      selectedIcon: Icon(Icons.category_rounded),
      label: 'Categorias',
    ),
    NavigationDestination(
      icon: Icon(Icons.credit_card_outlined),
      selectedIcon: Icon(Icons.credit_card_rounded),
      label: 'Faturas',
    ),
    NavigationDestination(
      icon: Icon(Icons.tune_outlined),
      selectedIcon: Icon(Icons.tune_rounded),
      label: 'Mais',
    ),
  ];

  /// The tabs whose contents depend on the selected period.
  static const _periodAware = {0, 1, 2, 3};

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

  @override
  Widget build(BuildContext context) {
    ref.listen(financeSnapshotProvider, (_, next) {
      final data = next.value;
      if (data != null) _syncReminders(data);
    });
    final state = ref.watch(financeSnapshotProvider);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    // Keeping the last snapshot on screen while a reload runs is what stops the
    // whole app blanking to a spinner after every write.
    final snapshot = state.value;
    if (snapshot != null) configureCurrency(snapshot.currencyCode);

    return Scaffold(
      body: Row(
        children: [
          if (wide)
            NavigationRail(
              extended: MediaQuery.sizeOf(context).width >= 1180,
              selectedIndex: index,
              onDestinationSelected: (value) => setState(() => index = value),
              leading: Padding(
                padding: const EdgeInsets.fromLTRB(8, 18, 8, 28),
                child: _Brand(compact: false, onSignOut: widget.onSignOut),
              ),
              trailing: widget.onSignOut == null
                  ? null
                  : IconButton(
                      tooltip: 'Sair',
                      onPressed: widget.onSignOut,
                      icon: const Icon(Icons.logout_rounded),
                    ),
              destinations: destinations
                  .map(
                    (item) => NavigationRailDestination(
                      icon: item.icon,
                      selectedIcon: item.selectedIcon,
                      label: Text(item.label),
                    ),
                  )
                  .toList(),
            ),
          Expanded(
            child: SafeArea(
              child: switch ((snapshot, state.hasError)) {
                (null, true) => _ErrorState(
                  failure: LoadFailure.from(state.error!),
                  onRetry: () => ref.invalidate(financeSnapshotProvider),
                ),
                (null, false) => const _SnapshotSkeleton(),
                (final data?, _) => Column(
                  children: [
                    if (!wide)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                        child: _Brand(
                          compact: true,
                          onSignOut: widget.onSignOut,
                        ),
                      ),
                    // One period control for the whole app. It used to be
                    // repeated inside four pages and missing from a fifth,
                    // which quietly ignored the selection.
                    if (_periodAware.contains(index))
                      Padding(
                        padding: EdgeInsets.fromLTRB(wide ? 32 : 18, 8, 18, 4),
                        child: PeriodFilterBar(
                          period: period,
                          onChanged: (value) => setState(() => period = value),
                        ),
                      ),
                    if (state.isLoading)
                      LinearProgressIndicator(
                        minHeight: 2,
                        backgroundColor: context.palette.hairline,
                      ),
                    if (data.truncated) const _TruncatedLedgerBanner(),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () => refreshFinanceSnapshot(ref),
                        child: _SelectedPage(
                          index: index,
                          snapshot: data,
                          period: period,
                          onPeriodChanged: (value) =>
                              setState(() => period = value),
                        ),
                      ),
                    ),
                  ],
                ),
              },
            ),
          ),
        ],
      ),
      // Below the wide breakpoint the pages hide their header buttons, so the
      // floating action button is the only path to creating a transaction.
      floatingActionButton: wide || snapshot == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => createTransaction(context, ref, snapshot),
              icon: const Icon(Icons.add),
              label: const Text('Transação'),
            ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (value) => setState(() => index = value),
              destinations: destinations,
            ),
    );
  }
}

class _SelectedPage extends StatelessWidget {
  const _SelectedPage({
    required this.index,
    required this.snapshot,
    required this.period,
    required this.onPeriodChanged,
  });
  final int index;
  final FinanceSnapshot snapshot;
  final FinancePeriod period;
  final ValueChanged<FinancePeriod> onPeriodChanged;
  @override
  Widget build(BuildContext context) => IndexedStack(
    index: index,
    children: [
      DashboardPage(
        snapshot: snapshot,
        period: period,
        onPeriodChanged: onPeriodChanged,
      ),
      TransactionsPage(
        snapshot: snapshot,
        period: period,
        onPeriodChanged: onPeriodChanged,
      ),
      CategoriesPage(
        snapshot: snapshot,
        period: period,
        onPeriodChanged: onPeriodChanged,
      ),
      CardsPage(snapshot: snapshot, period: period),
      MorePage(snapshot: snapshot, period: period),
    ],
  );
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
