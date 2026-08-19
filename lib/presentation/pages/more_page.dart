import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:financeiro_ai/application/providers.dart';
import 'package:financeiro_ai/core/breakpoints.dart';
import 'package:financeiro_ai/core/theme.dart';
import 'package:financeiro_ai/core/tokens.dart';
import 'package:financeiro_ai/domain/invoice_import.dart';
import 'package:financeiro_ai/domain/statement_import.dart';
import 'package:financeiro_ai/domain/statement_sheet.dart';
import 'package:financeiro_ai/presentation/widgets/statement_context_sheet.dart';
import 'package:financeiro_ai/domain/models.dart';
import 'package:financeiro_ai/domain/analytics.dart';
import 'package:financeiro_ai/presentation/pages/merchant_rules_page.dart';
import 'package:financeiro_ai/presentation/pages/projection_page.dart';
import 'package:financeiro_ai/presentation/pages/reminders_page.dart';
import 'package:financeiro_ai/presentation/pages/review_queue_page.dart';
import 'package:financeiro_ai/presentation/pages/accounts_page.dart';
import 'package:financeiro_ai/presentation/pages/data_page.dart';
import 'package:financeiro_ai/presentation/pages/holders_page.dart';
import 'package:financeiro_ai/presentation/pages/shortcut_tokens_page.dart';
import 'package:financeiro_ai/presentation/pages/subscriptions_page.dart';
import 'package:financeiro_ai/presentation/widgets/goal_form_sheet.dart';
import 'package:financeiro_ai/presentation/widgets/common.dart';
import 'package:financeiro_ai/presentation/widgets/invoice_review_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MorePage extends ConsumerWidget {
  const MorePage({super.key, required this.snapshot, required this.period});
  final FinanceSnapshot snapshot;
  final FinancePeriod period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
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
            final goals = SectionCard(
              title: 'Metas',
              tooltip: 'Criar uma meta',
              onTap: () => editGoal(context, ref),
              trailing: IconButton(
                tooltip: 'Nova meta',
                onPressed: () => editGoal(context, ref),
                icon: const Icon(Icons.add_rounded),
              ),
              child: Column(
                children: snapshot.goals
                    .map(
                      (goal) => Semantics(
                        label: 'Ver detalhes da meta ${goal.name}',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => editGoal(context, ref, existing: goal),
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
                                        color: context.palette.brand,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                LinearProgressIndicator(
                                  value: goal.progress,
                                  minHeight: 9,
                                  color: context.palette.brand,
                                  backgroundColor: context.palette.brandSoft,
                                  borderRadius: BorderRadius.circular(10),
                                ),
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
        SectionCard(
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
                color: context.palette.warning,
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
                onTap: () => _pickInvoice(context, ref),
              ),
              _OperationTile(
                icon: Icons.table_chart_outlined,
                color: const Color(0xFF3F6E8C),
                title: 'Importar extrato do banco',
                subtitle: 'Planilha CSV ou XLSX, sem passo manual fora do app',
                tooltip:
                    'Ler o extrato exportado pelo banco e revisar antes '
                    'de gravar',
                onTap: () => _pickStatement(context, ref),
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
                color: context.palette.brand,
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
                color: context.palette.danger,
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
      ],
    );
  }

  Future<void> _pickInvoice(BuildContext context, WidgetRef ref) async {
    try {
      const jsonType = XTypeGroup(
        label: 'JSON do Finora',
        extensions: ['json'],
        mimeTypes: ['application/json'],
        uniformTypeIdentifiers: ['public.json'],
      );
      final picked = await openFile(acceptedTypeGroups: const [jsonType]);
      if (picked == null || !context.mounted) return;
      final bytes = await picked.readAsBytes();
      final document = InvoiceImportDocument.decode(utf8.decode(bytes));
      if (!context.mounted) return;
      await _runImport(context, ref, document);
    } on InvoiceImportException catch (error) {
      if (context.mounted) _message(context, error.message, error: true);
    } catch (error) {
      if (context.mounted) {
        _message(context, _friendlyImportError(error), error: true);
      }
    }
  }

  /// Reads a bank's own spreadsheet export, so the ledger stops depending on a
  /// JSON produced outside the app.
  Future<void> _pickStatement(BuildContext context, WidgetRef ref) async {
    try {
      const sheetType = XTypeGroup(
        label: 'Extrato (CSV ou XLSX)',
        extensions: ['csv', 'txt', 'xlsx'],
      );
      final picked = await openFile(acceptedTypeGroups: const [sheetType]);
      if (picked == null || !context.mounted) return;

      final bytes = await picked.readAsBytes();
      final isXlsx = picked.name.toLowerCase().endsWith('.xlsx');
      final cells = isXlsx
          ? readXlsxCells(bytes)
          // Falls back to Latin-1 because a statement exported by an older
          // banking site is not always UTF-8, and a decode failure would look
          // like an unreadable file rather than an encoding mismatch.
          : readDelimitedCells(_decodeText(bytes));
      final parse = parseStatementSheet(cells);

      if (!context.mounted) return;
      final statementContext = await askStatementContext(
        context,
        cards: snapshot.cards,
        parse: parse,
        fileName: picked.name,
      );
      if (statementContext == null || !context.mounted) return;

      await _runImport(
        context,
        ref,
        buildStatementImport(parse, statementContext),
      );
    } on StatementParseException catch (error) {
      if (context.mounted) _message(context, error.message, error: true);
    } on InvoiceImportException catch (error) {
      if (context.mounted) _message(context, error.message, error: true);
    } catch (error) {
      if (context.mounted) {
        _message(context, _friendlyImportError(error), error: true);
      }
    }
  }

  /// Preview, review and write. Shared by both readers on purpose: a second
  /// path into the ledger would be a second place for the duplicate check and
  /// the category rules to drift.
  /// UTF-8 when it decodes, Latin-1 otherwise.
  ///
  /// A statement exported by an older banking site is not always UTF-8, and a
  /// hard decode failure would surface as "arquivo ilegível" when the file is
  /// perfectly readable in another encoding.
  String _decodeText(Uint8List bytes) {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return latin1.decode(bytes, allowInvalid: true);
    }
  }

  Future<void> _runImport(
    BuildContext context,
    WidgetRef ref,
    InvoiceImportDocument document,
  ) async {
    var loadingOpen = false;
    try {
      _showLoading(context, 'Validando e conciliando…');
      loadingOpen = true;
      final preview = await ref
          .read(financeRepositoryProvider)
          .previewInvoiceImport(document);
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      loadingOpen = false;
      final reviewedDocument = await showInvoiceReviewDialog(
        context,
        document: document,
        preview: preview,
        categories: snapshot.categories,
      );
      if (reviewedDocument == null || !context.mounted) return;

      _showLoading(context, 'Conferindo revisão…');
      loadingOpen = true;
      final finalPreview = await ref
          .read(financeRepositoryProvider)
          .previewInvoiceImport(reviewedDocument);
      final missingCategoriesApproved =
          reviewedDocument.createMissingCategories &&
          finalPreview.missingCategories.isNotEmpty;
      if (finalPreview.alreadyImported ||
          (!finalPreview.canImport && !missingCategoriesApproved)) {
        throw const InvoiceImportException(
          'Ainda existem categorias ou duplicidades que impedem a importação.',
        );
      }
      if (!context.mounted) return;
      final result = await ref
          .read(financeRepositoryProvider)
          .importInvoice(reviewedDocument);
      ref.invalidate(financeSnapshotProvider);
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      loadingOpen = false;
      _message(
        context,
        result.duplicateBatch
            ? 'Esta fatura já havia sido importada.'
            : 'Fatura importada: ${result.created} novos, ${result.reconciled} conciliados e ${result.reviews} para revisão.',
      );
    } on InvoiceImportException catch (error) {
      if (context.mounted) {
        if (loadingOpen) _closeLoading(context);
        _message(context, error.message, error: true);
      }
    } catch (error) {
      if (context.mounted) {
        if (loadingOpen) _closeLoading(context);
        _message(context, _friendlyImportError(error), error: true);
      }
    }
  }

  void _showLoading(BuildContext context, String label) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _closeLoading(BuildContext context) {
    final navigator = Navigator.of(context, rootNavigator: true);
    if (navigator.canPop()) navigator.pop();
  }

  void _message(BuildContext context, String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? context.palette.danger : context.palette.brand,
      ),
    );
  }

  String _friendlyImportError(Object error) {
    final text = '$error';
    if (text.contains('card_not_found')) {
      return 'O cartão final informado no JSON não está cadastrado ou está inativo.';
    }
    if (text.contains('missing_categories')) {
      return 'O JSON usa categorias que ainda não existem no Finora.';
    }
    if (text.contains('reconciled_total_mismatch')) {
      return 'A conciliação não fechou com o total da fatura. Nada foi importado.';
    }
    if (text.contains('personal_total_mismatch')) {
      return 'As decisões item a item não fecharam com o total pessoal. Nada foi importado.';
    }
    return 'Não foi possível importar: $text';
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
                  color: context.palette.brandSoft,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  Icons.contactless_rounded,
                  color: context.palette.brand,
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
          backgroundColor: context.palette.brand,
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
