import 'package:financeiro_ai/application/providers.dart';
import 'package:financeiro_ai/core/category_visuals.dart';
import 'package:financeiro_ai/core/theme.dart';
import 'package:financeiro_ai/domain/amount_input.dart';
import 'package:financeiro_ai/domain/catalog_drafts.dart';
import 'package:financeiro_ai/domain/models.dart';
import 'package:financeiro_ai/domain/transaction_draft.dart';
import 'package:financeiro_ai/presentation/widgets/ledger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> editCategory(
  BuildContext context,
  WidgetRef ref, {
  FinanceCategory? existing,
}) async {
  final saved = await showResponsiveSurface<bool>(
    context,
    builder: (context) => _CategoryForm(
      existing: existing,
      onSave: (draft) async {
        await ref.read(financeRepositoryProvider).saveCategory(draft);
        await refreshFinanceSnapshot(ref);
      },
    ),
  );
  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          existing == null ? 'Categoria criada.' : 'Categoria atualizada.',
        ),
        backgroundColor: context.palette.accent,
      ),
    );
  }
}

class _CategoryForm extends StatefulWidget {
  const _CategoryForm({required this.onSave, this.existing});
  final Future<void> Function(CategoryDraft draft) onSave;
  final FinanceCategory? existing;

  @override
  State<_CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends State<_CategoryForm> {
  late final TextEditingController _name;
  late final TextEditingController _budget;
  late Color _color;
  late String _iconName;
  late bool _hasBudget;
  bool _saving = false;
  String? _failure;
  CategoryDraftErrors _errors = const CategoryDraftErrors();

  @override
  void initState() {
    super.initState();
    final category = widget.existing;
    _name = TextEditingController(text: category?.name ?? '');
    _hasBudget = (category?.monthlyBudget ?? 0) > 0;
    _budget = TextEditingController(
      text: category?.monthlyBudget == null
          ? ''
          : category!.monthlyBudget!.toStringAsFixed(2).replaceAll('.', ','),
    );
    _color = category?.color ?? categoryColors.first;
    _iconName = category == null ? 'category' : categoryIconName(category.icon);
  }

  @override
  void dispose() {
    _name.dispose();
    _budget.dispose();
    super.dispose();
  }

  CategoryDraft _buildDraft() => CategoryDraft(
    id: widget.existing?.id,
    name: _name.text,
    color: _color,
    iconName: _iconName,
    // No budget is not the same as a budget of zero: zero would report every
    // purchase as over budget.
    monthlyBudget: _hasBudget ? parseAmountInput(_budget.text) : null,
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
    } on FinanceWriteException catch (error) {
      if (mounted) {
        setState(() {
          _failure = error.message;
          _saving = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _failure = 'Não foi possível salvar. Verifique sua conexão.';
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .88,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SheetHeader(
                title: widget.existing == null
                    ? 'Nova categoria'
                    : 'Editar categoria',
              ),
              const SizedBox(height: 20),
              // A live preview, because the colour and icon are what make a
              // category recognisable at a glance in every other screen.
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _color.withValues(alpha: .16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(categoryIconFor(_iconName), color: _color),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: TextField(
                      controller: _name,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Nome',
                        errorText: _errors.name,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text('Cor', style: _labelStyle(context)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: categoryColors
                    .map(
                      (color) => _Swatch(
                        color: color,
                        selected: color.toARGB32() == _color.toARGB32(),
                        onTap: () => setState(() => _color = color),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 20),
              Text('Ícone', style: _labelStyle(context)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: categoryIcons.entries
                    .map(
                      (entry) => _IconChoice(
                        icon: entry.value,
                        color: _color,
                        selected: entry.key == _iconName,
                        onTap: () => setState(() => _iconName = entry.key),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _hasBudget,
                onChanged: (value) => setState(() => _hasBudget = value),
                title: const Text(
                  'Definir orçamento mensal',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (_hasBudget)
                TextField(
                  controller: _budget,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Orçamento',
                    hintText: '0,00',
                    prefixText: 'R\$ ',
                    prefixIcon: const Icon(Icons.flag_outlined),
                    errorText: _errors.budget,
                  ),
                ),
              if (_failure != null) ...[
                const SizedBox(height: 12),
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
              const SizedBox(height: 20),
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
                              ? 'Criar categoria'
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

  TextStyle _labelStyle(BuildContext context) => TextStyle(
    fontWeight: FontWeight.w700,
    fontSize: 13,
    color: context.palette.inkMuted,
  );
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: selected
              ? Border.all(color: context.palette.ink, width: 3)
              : null,
        ),
        child: selected
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 19)
            : null,
      ),
    ),
  );
}

class _IconChoice extends StatelessWidget {
  const _IconChoice({
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: .18)
              : context.palette.canvas,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : context.palette.rule,
            width: selected ? 2 : 1,
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: selected ? color : context.palette.inkMuted,
        ),
      ),
    ),
  );
}
