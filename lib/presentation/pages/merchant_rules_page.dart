import 'package:financeiro_ai/core/theme.dart';
import 'package:financeiro_ai/domain/merchant_rule.dart';
import 'package:financeiro_ai/domain/models.dart';
import 'package:financeiro_ai/presentation/widgets/ledger.dart';
import 'package:financeiro_ai/core/errors/failure.dart';
import 'package:financeiro_ai/core/logging/logger.dart';
import 'package:financeiro_ai/presentation/failure_copy.dart';
import 'package:financeiro_ai/presentation/cubits/catalog_cubits.dart';
import 'package:financeiro_ai/presentation/cubits/finance_cubit.dart';
import 'package:financeiro_ai/domain/repositories/repositories.dart';
import 'package:financeiro_ai/core/state/load_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class MerchantRulesPage extends StatefulWidget {
  const MerchantRulesPage({super.key});


  @override
  State<MerchantRulesPage> createState() => _MerchantRulesPageState();
}

class _MerchantRulesPageState extends State<MerchantRulesPage> {
  @override
  void initState() {
    super.initState();
    // The queue used to be a FutureProvider, which fetched on first
    // watch. A cubit does not, so the screen asks — which keeps the
    // load off the app's first paint, where it never belonged.
    context.read<MerchantRulesCubit>().loadOnce();
  }

  @override
  Widget build(BuildContext context) {
    final rules = context.watch<MerchantRulesCubit>().state;
    final snapshot = context.watch<FinanceCubit>().state.snapshot;

    return Scaffold(
      appBar: AppBar(title: const Text('Regras de estabelecimento')),
      floatingActionButton: snapshot == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => editRule(context, snapshot),
              icon: const Icon(Icons.add),
              label: const Text('Nova regra'),
            ),
      body: RefreshIndicator(
        onRefresh: () => context.read<MerchantRulesCubit>().reload(),
        child: switch (rules) {
          LoadFailed() => _RulesMessage(
            icon: Icons.cloud_off_rounded,
            color: context.palette.negative,
            title: 'Não foi possível carregar as regras',
            body: 'Verifique sua conexão e tente novamente.',
            onRetry: () => context.read<MerchantRulesCubit>().reload(),
          ),
          LoadSuccess(data: final items) ||
          LoadReloading(previous: final items) => items.isEmpty
              ? _RulesMessage(
                  icon: Icons.psychology_alt_rounded,
                  color: context.palette.accent,
                  title: 'Nenhuma regra ainda',
                  body:
                      'Uma regra diz “sempre que o nome contiver IFOOD, use Alimentação”. '
                      'Ela decide a categoria na captura do Atalho quando você não '
                      'escolhe uma na hora, poupando a correção depois.',
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
                          'Aplicadas na captura do Atalho, de cima para baixo: a '
                          'primeira que casar decide a categoria. Se você escolher '
                          'a categoria no próprio Atalho, sua escolha prevalece.',
                          style: TextStyle(color: context.palette.inkMuted),
                        ),
                      );
                    }
                    final rule = items[index - 1];
                    return _RuleTile(
                      rule: rule,
                      matches: snapshot?.transactions
                          .where((item) => rule.matches(item.merchant))
                          .length,
                      onEdit: snapshot == null
                          ? null
                          : () => editRule(
                              context,
                              snapshot,
                              existing: rule,
                            ),
                      onDelete: () => _confirmDelete(context, rule),
                    );
                  },
                ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    MerchantRule rule,
  ) async {
    final review = context.read<ReviewRepository>();
    final merchantRules = context.read<MerchantRulesCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir regra?'),
        content: Text(
          'A regra “${rule.pattern} → ${rule.categoryName}” deixará de ser aplicada '
          'às próximas capturas. Lançamentos já categorizados não mudam.',
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
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await review.deleteMerchantRule(rule.id);
      await merchantRules.reload();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Regra excluída.'),
            backgroundColor: context.palette.accent,
          ),
        );
      }
    } on Failure catch (failure) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(FailureCopy.of(failure).short),
            backgroundColor: context.palette.negative,
          ),
        );
      }
    }
  }
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({
    required this.rule,
    required this.matches,
    required this.onEdit,
    required this.onDelete,
  });
  final MerchantRule rule;
  final int? matches;
  final VoidCallback? onEdit;
  final VoidCallback onDelete;

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
                        rule.pattern,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 15),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        rule.categoryName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.palette.accent,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (!rule.active) ...[
                      const SizedBox(width: 8),
                      const Chip(
                        label: Text('Inativa', style: TextStyle(fontSize: 11)),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  matches == null
                      ? 'Prioridade ${rule.priority}'
                      : 'Prioridade ${rule.priority} • pega $matches ${matches == 1 ? 'lançamento' : 'lançamentos'} do histórico',
                  style: TextStyle(
                    color: context.palette.inkMuted,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined)),
          IconButton(
            onPressed: onDelete,
            icon: Icon(
              Icons.delete_outline_rounded,
              color: context.palette.negative,
            ),
          ),
        ],
      ),
    ),
  );
}

class _RulesMessage extends StatelessWidget {
  const _RulesMessage({
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

/// Opens the rule editor. Shared so the rules screen and any future
/// "learn this categorization" shortcut behave identically.
Future<void> editRule(
  BuildContext context,
  FinanceSnapshot snapshot, {
  MerchantRule? existing,
  String? suggestedPattern,
}) async {
  final saved = await showResponsiveSurface<bool>(
    context,
    builder: (context) => _RuleForm(
      snapshot: snapshot,
      existing: existing,
      suggestedPattern: suggestedPattern,
      onSave: (draft) async {
        final review = context.read<ReviewRepository>();
        final merchantRules = context.read<MerchantRulesCubit>();
        await review.saveMerchantRule(draft);
        await merchantRules.reload();
      },
    ),
  );
  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(existing == null ? 'Regra criada.' : 'Regra atualizada.'),
        backgroundColor: context.palette.accent,
      ),
    );
  }
}

class _RuleForm extends StatefulWidget {
  const _RuleForm({
    required this.snapshot,
    required this.onSave,
    this.existing,
    this.suggestedPattern,
  });
  final FinanceSnapshot snapshot;
  final Future<void> Function(MerchantRuleDraft draft) onSave;
  final MerchantRule? existing;
  final String? suggestedPattern;

  @override
  State<_RuleForm> createState() => _RuleFormState();
}

class _RuleFormState extends State<_RuleForm> {
  late final TextEditingController _pattern;
  late final TextEditingController _priority;
  String? _categoryId;
  bool _active = true;
  bool _saving = false;
  String? _failure;
  MerchantRuleErrors _errors = const MerchantRuleErrors();

  @override
  void initState() {
    super.initState();
    _pattern = TextEditingController(
      text: widget.existing?.pattern ?? widget.suggestedPattern ?? '',
    );
    _priority = TextEditingController(
      text: (widget.existing?.priority ?? 100).toString(),
    );
    _categoryId = widget.existing?.categoryId;
    _active = widget.existing?.active ?? true;
    _pattern.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _pattern.dispose();
    _priority.dispose();
    super.dispose();
  }

  MerchantRuleDraft _buildDraft() => MerchantRuleDraft(
    id: widget.existing?.id,
    pattern: _pattern.text,
    categoryId: _categoryId ?? '',
    priority: int.tryParse(_priority.text) ?? 100,
    active: _active,
  );

  Future<void> _submit() async {
    final draft = _buildDraft();
    final errors = draft.validate();
    setState(() {
      _errors = errors;
      _failure = null;
    });
    if (!errors.isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(draft);
      if (mounted) Navigator.of(context).pop(true);
    } on Failure catch (failure) {
      if (mounted) {
        setState(() {
          _failure = FailureCopy.of(failure).short;
          _saving = false;
        });
      }
    } catch (error, stack) {
      appLogger.error('saveMerchantRule', error, stack);
      if (mounted) {
        setState(() {
          _failure = FailureCopy.from(error, stack).short;
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final typed = _pattern.text.trim();
    final preview = typed.length < 3
        ? const <FinanceTransaction>[]
        : widget.snapshot.transactions
              .where(
                (item) =>
                    item.merchant.toLowerCase().contains(typed.toLowerCase()),
              )
              .toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .88,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.existing == null ? 'Nova regra' : 'Editar regra',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Quando o nome do estabelecimento contiver o trecho abaixo, a categoria escolhida é aplicada automaticamente.',
                  style: TextStyle(color: context.palette.inkMuted),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _pattern,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'Trecho do nome',
                    hintText: 'IFOOD',
                    prefixIcon: const Icon(Icons.search_rounded),
                    errorText: _errors.pattern,
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _categoryId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Categoria',
                    prefixIcon: const Icon(Icons.label_outline_rounded),
                    errorText: _errors.category,
                  ),
                  items: widget.snapshot.categories
                      .map(
                        (category) => DropdownMenuItem(
                          value: category.id,
                          child: Text(
                            category.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _categoryId = value),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _priority,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Prioridade',
                    helperText:
                        'O menor número decide primeiro quando duas regras casam.',
                    prefixIcon: Icon(Icons.low_priority_rounded),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _active,
                  onChanged: (value) => setState(() => _active = value),
                  title: const Text(
                    'Regra ativa',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                // Shows the blast radius before the rule is saved.
                if (typed.length >= 3)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: context.palette.canvas,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          preview.isEmpty
                              ? 'Nenhum lançamento do histórico casa com “$typed”.'
                              : 'Casa com ${preview.length} ${preview.length == 1 ? 'lançamento' : 'lançamentos'} do histórico:',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        ...preview
                            .take(4)
                            .map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(top: 7),
                                child: Text(
                                  '• ${item.merchant} — ${item.category}',
                                  style: TextStyle(
                                    color: context.palette.inkMuted,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                        if (preview.length > 4)
                          Padding(
                            padding: const EdgeInsets.only(top: 7),
                            child: Text(
                              'e mais ${preview.length - 4}.',
                              style: TextStyle(
                                color: context.palette.inkSubtle,
                                fontSize: 13,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                if (_failure != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: context.palette.negative.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          color: context.palette.negative,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _failure!,
                            style: TextStyle(
                              color: context.palette.negative,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: _saving ? null : _submit,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    child: _saving
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            widget.existing == null
                                ? 'Criar regra'
                                : 'Salvar alterações',
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
