
import 'package:financeiro_ai/core/theme/breakpoints.dart';
import 'package:financeiro_ai/core/theme/theme.dart';
import 'package:financeiro_ai/core/theme/tokens.dart';
import 'package:financeiro_ai/features/ledger/domain/entities/models.dart';
import 'package:financeiro_ai/features/overview/domain/analytics.dart';
import 'package:financeiro_ai/features/review/presenter/pages/merchant_rules_page.dart';
import 'package:financeiro_ai/features/invoices/presenter/pages/projection_page.dart';
import 'package:financeiro_ai/features/reminders/presenter/pages/reminders_page.dart';
import 'package:financeiro_ai/features/review/presenter/pages/review_queue_page.dart';
import 'package:financeiro_ai/features/catalog/presenter/pages/accounts_page.dart';
import 'package:financeiro_ai/features/imports/presenter/pages/data_page.dart';
import 'package:financeiro_ai/features/catalog/presenter/pages/holders_page.dart';
import 'package:financeiro_ai/features/settings/presenter/pages/shortcut_tokens_page.dart';
import 'package:financeiro_ai/features/invoices/presenter/pages/subscriptions_page.dart';
import 'package:financeiro_ai/features/catalog/presenter/widgets/goal_form_sheet.dart';
import 'package:financeiro_ai/core/design_system/common.dart';
import 'package:financeiro_ai/core/design_system/ledger.dart';
import 'package:financeiro_ai/features/settings/presenter/cubits/appearance_cubit.dart';
import 'package:financeiro_ai/core/theme/typography.dart';
import 'package:financeiro_ai/features/imports/presenter/import_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key, required this.snapshot, required this.period});
  final FinanceSnapshot snapshot;
  final FinancePeriod period;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        Breakpoint.of(context).gutter,
        Space.xl,
        Breakpoint.of(context).gutter,
        Space.xxxl,
      ),
      children: [
        const PageHeading(
          title: 'Planejamento e automações',
          subtitle: 'Metas, revisões, importações e conexão com o Atalhos.',
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            final split = constraints.maxWidth >= 850;
            final goals = RuledSection(
              title: 'Metas',
              tooltip: 'Criar uma meta',
              onTap: () => editGoal(context),
              trailing: IconButton(
                tooltip: 'Nova meta',
                onPressed: () => editGoal(context),
                icon: const Icon(Icons.add_rounded),
              ),
              child: Column(
                children: snapshot.goals
                    .map(
                      (goal) => Semantics(
                        label: 'Ver detalhes da meta ${goal.name}',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => editGoal(context, existing: goal),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 18),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        goal.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${(goal.progress * 100).round()}%',
                                      style: TextStyle(
                                        color: context.palette.accent,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                RuleBar(value: goal.progress),
                                const SizedBox(height: 6),
                                // A Spacer between two rigid amounts has no
                                // give: at 1.3x text the pair overflowed by
                                // 66px. spaceBetween plus Flexible lets the
                                // values wrap instead.
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        currency.format(goal.current),
                                        style: TextStyle(
                                          color: context.palette.inkMuted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    Flexible(
                                      child: Text(
                                        currency.format(goal.target),
                                        textAlign: TextAlign.end,
                                        style: TextStyle(
                                          color: context.palette.inkMuted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            );
            final automation = const _AutomationCard();
            return split
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: goals),
                      const SizedBox(width: 14),
                      Expanded(child: automation),
                    ],
                  )
                : Column(
                    children: [goals, const SizedBox(height: 14), automation],
                  );
          },
        ),
        const SizedBox(height: 14),
        RuledSection(
          title: 'Operação',
          child: Column(
            children: [
              _OperationTile(
                icon: Icons.query_stats_rounded,
                color: const Color(0xFF5D65A8),
                title: 'Projeção',
                subtitle: 'Faturas, parcelas e conta nos próximos seis meses',
                tooltip: 'Abrir a projeção financeira',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('Projeção')),
                      body: ProjectionPage(
                        snapshot: snapshot,
                        period: period,
                        onPeriodChanged: (_) {},
                      ),
                    ),
                  ),
                ),
              ),
              _OperationTile(
                icon: Icons.account_balance_rounded,
                color: const Color(0xFF477D9B),
                title: 'Contas',
                subtitle: snapshot.accounts.isEmpty
                    ? 'Onde o dinheiro fica fora do cartão'
                    : '${snapshot.accounts.length} cadastradas',
                tooltip: 'Gerenciar contas e ver saldos',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AccountsPage(snapshot: snapshot),
                  ),
                ),
              ),
              _OperationTile(
                icon: Icons.subscriptions_rounded,
                color: const Color(0xFF7D63A8),
                title: 'Assinaturas',
                subtitle: 'Quanto por mês em cobranças que se repetem',
                tooltip: 'Ver cobranças recorrentes detectadas no histórico',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SubscriptionsPage(snapshot: snapshot),
                  ),
                ),
              ),
              _OperationTile(
                icon: Icons.rule_folder_rounded,
                color: context.palette.pending,
                title: 'Revisões pendentes',
                subtitle: snapshot.pendingReviews == 0
                    ? 'Nada aguardando sua confirmação'
                    : '${snapshot.pendingReviews} ${snapshot.pendingReviews == 1 ? 'transação precisa' : 'transações precisam'} de confirmação',
                tooltip: 'Abrir a fila de revisões pendentes',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ReviewQueuePage(),
                  ),
                ),
              ),
              _OperationTile(
                icon: Icons.upload_file_rounded,
                color: Color(0xFF5D65A8),
                title: 'Importar JSON do ChatGPT',
                subtitle: 'Validar, conciliar e cadastrar uma fatura',
                tooltip:
                    'Selecionar o JSON e revisar a importação antes de gravar',
                onTap: () => pickInvoiceImport(context, snapshot: snapshot),
              ),
              _OperationTile(
                icon: Icons.table_chart_outlined,
                color: const Color(0xFF3F6E8C),
                title: 'Importar extrato do banco',
                subtitle: 'Planilha CSV ou XLSX, sem passo manual fora do app',
                tooltip:
                    'Ler o extrato exportado pelo banco e revisar antes '
                    'de gravar',
                onTap: () => pickStatementImport(context, snapshot: snapshot),
              ),
              _OperationTile(
                icon: Icons.download_rounded,
                color: const Color(0xFF6B7B58),
                title: 'Seus dados',
                subtitle: 'Exportar CSV e ver o histórico de importações',
                tooltip: 'Exportar seus lançamentos e revisar importações',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => DataPage(snapshot: snapshot),
                  ),
                ),
              ),
              _OperationTile(
                icon: Icons.people_alt_rounded,
                color: context.palette.accent,
                title: 'Portadores',
                subtitle: snapshot.holders.isEmpty
                    ? 'Defina quais gastos entram nas suas finanças'
                    : '${snapshot.holders.length} cadastrados',
                tooltip: 'Gerenciar titulares e cartões adicionais',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => HoldersPage(snapshot: snapshot),
                  ),
                ),
              ),
              _OperationTile(
                icon: Icons.notifications_active_rounded,
                color: const Color(0xFFA8763E),
                title: 'Lembretes',
                subtitle: 'Avisar antes de a fatura vencer',
                tooltip: 'Configurar notificações de vencimento',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => RemindersPage(snapshot: snapshot),
                  ),
                ),
              ),
              _OperationTile(
                icon: Icons.psychology_alt_rounded,
                color: context.palette.negative,
                title: 'Regras de estabelecimento',
                subtitle: 'Categorize compras recorrentes automaticamente',
                tooltip: 'Ver e editar regras de categorização',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const MerchantRulesPage(),
                  ),
                ),
              ),
            ],
          ),
        ),
        const _Appearance(),
      ],
    );
  }

}

class _AutomationCard extends StatelessWidget {
  const _AutomationCard();
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Abrir instruções e estado da automação do Apple Pay',
    child: Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showDetailSheet(
          context,
          title: 'Automação Apple Pay',
          description:
              'Depois do pagamento, o Atalho coleta os dados e envia à função segura do Finora.',
          child: const Column(
            children: [
              DetailValue(label: 'Captura', value: 'Atalhos do iOS'),
              DetailValue(label: 'Autenticação', value: 'Token revogável'),
              DetailValue(label: 'Destino', value: 'Supabase Edge Function'),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.palette.accentSoft,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  Icons.contactless_rounded,
                  color: context.palette.accent,
                  size: 28,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Apple Pay conectado',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
              const SizedBox(height: 7),
              Text(
                'O Atalho envia estabelecimento, valor, cartão e categoria para uma Edge Function segura.',
                style: TextStyle(color: context.palette.inkMuted, height: 1.4),
              ),
              const SizedBox(height: 18),
              const _Step(number: '1', label: 'Pague com Apple Pay'),
              const _Step(number: '2', label: 'Escolha a categoria'),
              const _Step(number: '3', label: 'A transação aparece aqui'),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ShortcutTokensPage(),
                    ),
                  ),
                  icon: const Icon(Icons.key_rounded),
                  label: const Text('Gerenciar tokens'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.label});
  final String number;
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: context.palette.accent,
          child: Text(
            number,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Unbounded, the label overflowed the row by 66px at 390pt — the
        // width of an iPhone 15. Found by the golden baseline.
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _OperationTile extends StatelessWidget {
  const _OperationTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.tooltip,
    this.onTap,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String tooltip;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    label: tooltip,
    child: ListTile(
      onTap:
          onTap ??
          () => showDetailSheet(
            context,
            title: title,
            description: subtitle,
            child: const Text(
              'Esta área usará os dados sincronizados do Supabase.',
            ),
          ),
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
    ),
  );
}

/// The theme, where someone can actually find it.
///
/// PR 3 put the control in the sidebar's footer, and the sidebar only exists at
/// 600pt and up — so on a phone the product had two themes and no way to choose
/// between them. It belongs in Ajustes anyway, which is where the information
/// architecture said it would be.
///
/// Three named choices rather than a cycling icon: an icon that rotates through
/// states cannot tell you what the states are, and "Sistema" is a real answer,
/// not the absence of one.
class _Appearance extends StatelessWidget {
  const _Appearance();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final current = context.watch<AppearanceCubit>().state;

    return RuledSection(
      title: 'Aparência',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Vale para este aparelho e fica guardado.',
            style: context.type.bodySm.copyWith(color: palette.inkMuted),
          ),
          const SizedBox(height: Space.sm),
          IntrinsicHeight(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: palette.ruleStrong),
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
              clipBehavior: Clip.antiAlias,
              child: Row(
                children: [
                  for (final mode in ThemeMode.values) ...[
                    if (mode != ThemeMode.values.first)
                      Container(
                        width: Strokes.hairline,
                        color: palette.ruleStrong,
                      ),
                    Expanded(
                      child: Semantics(
                        selected: mode == current,
                        button: true,
                        label: 'Tema ${mode.label}',
                        child: InkWell(
                          onTap: () =>
                              context.read<AppearanceCubit>().set(mode),
                          child: Container(
                            color: mode == current ? palette.ink : null,
                            padding: const EdgeInsets.symmetric(
                              vertical: Space.xs + 2,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  mode.icon,
                                  size: 17,
                                  color: mode == current
                                      ? palette.canvas
                                      : palette.inkMuted,
                                ),
                                const SizedBox(height: Space.xxs),
                                Text(
                                  mode.label,
                                  style: context.type.bodySm.copyWith(
                                    color: mode == current
                                        ? palette.canvas
                                        : palette.inkMuted,
                                    fontWeight: mode == current
                                        ? FontWeight.w600
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
