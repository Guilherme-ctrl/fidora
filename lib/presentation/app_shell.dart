import 'package:financeiro_ai/application/providers.dart';
import 'package:financeiro_ai/core/theme.dart';
import 'package:financeiro_ai/domain/analytics.dart';
import 'package:financeiro_ai/domain/load_failure.dart';
import 'package:financeiro_ai/domain/models.dart';
import 'package:financeiro_ai/presentation/pages/cards_page.dart';
import 'package:financeiro_ai/presentation/pages/categories_page.dart';
import 'package:financeiro_ai/presentation/pages/dashboard_page.dart';
import 'package:financeiro_ai/presentation/pages/more_page.dart';
import 'package:financeiro_ai/presentation/pages/projection_page.dart';
import 'package:financeiro_ai/presentation/pages/transactions_page.dart';
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
  FinancePeriod period = FinancePeriod.month(DateTime.now());

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
      icon: Icon(Icons.query_stats_outlined),
      selectedIcon: Icon(Icons.query_stats_rounded),
      label: 'Projeção',
    ),
    NavigationDestination(
      icon: Icon(Icons.tune_outlined),
      selectedIcon: Icon(Icons.tune_rounded),
      label: 'Mais',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(financeSnapshotProvider);
    final wide = MediaQuery.sizeOf(context).width >= 900;
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
              child: state.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => _ErrorState(
                  failure: LoadFailure.from(error),
                  onRetry: () => ref.invalidate(financeSnapshotProvider),
                ),
                data: (snapshot) => Column(
                  children: [
                    if (!wide)
                      Padding(
                        padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
                        child: _Brand(
                          compact: true,
                          onSignOut: widget.onSignOut,
                        ),
                      ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () => refreshFinanceSnapshot(ref),
                        child: _SelectedPage(
                          index: index,
                          snapshot: snapshot,
                          period: period,
                          onPeriodChanged: (value) =>
                              setState(() => period = value),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      // Below the wide breakpoint the pages hide their header buttons, so the
      // floating action button is the only path to creating a transaction.
      floatingActionButton: wide
          ? null
          : state.maybeWhen(
              data: (snapshot) => FloatingActionButton.extended(
                onPressed: () => createTransaction(context, ref, snapshot),
                icon: const Icon(Icons.add),
                label: const Text('Transação'),
              ),
              orElse: () => null,
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
      CardsPage(snapshot: snapshot),
      ProjectionPage(
        snapshot: snapshot,
        period: period,
        onPeriodChanged: onPeriodChanged,
      ),
      MorePage(snapshot: snapshot),
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
