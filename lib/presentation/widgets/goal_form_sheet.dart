import 'package:clock/clock.dart';
import 'package:financeiro_ai/application/providers.dart';
import 'package:financeiro_ai/core/theme.dart';
import 'package:financeiro_ai/domain/amount_input.dart';
import 'package:financeiro_ai/domain/catalog_drafts.dart';
import 'package:financeiro_ai/domain/models.dart';
import 'package:financeiro_ai/presentation/widgets/common.dart';
import 'package:financeiro_ai/presentation/widgets/ledger.dart';
import 'package:financeiro_ai/core/errors/failure.dart';
import 'package:financeiro_ai/core/logging/logger.dart';
import 'package:financeiro_ai/presentation/failure_copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> editGoal(
  BuildContext context,
  WidgetRef ref, {
  Goal? existing,
}) async {
  final saved = await showResponsiveSurface<bool>(
    context,
    builder: (context) => _GoalForm(
      existing: existing,
      onSave: (draft) async {
        await ref.read(financeRepositoryProvider).saveGoal(draft);
        await refreshFinanceSnapshot(ref);
      },
    ),
  );
  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(existing == null ? 'Meta criada.' : 'Meta atualizada.'),
        backgroundColor: context.palette.accent,
      ),
    );
  }
}

class _GoalForm extends StatefulWidget {
  const _GoalForm({required this.onSave, this.existing});
  final Future<void> Function(GoalDraft draft) onSave;
  final Goal? existing;

  @override
  State<_GoalForm> createState() => _GoalFormState();
}

class _GoalFormState extends State<_GoalForm> {
  late final TextEditingController _name;
  late final TextEditingController _target;
  late final TextEditingController _current;
  DateTime? _targetDate;
  bool _saving = false;
  String? _failure;
  GoalDraftErrors _errors = const GoalDraftErrors();

  String _money(double value) => value.toStringAsFixed(2).replaceAll('.', ',');

  @override
  void initState() {
    super.initState();
    final goal = widget.existing;
    _name = TextEditingController(text: goal?.name ?? '');
    _target = TextEditingController(
      text: goal == null ? '' : _money(goal.target),
    );
    _current = TextEditingController(
      text: goal == null ? '' : _money(goal.current),
    );
    _targetDate = goal?.targetDate;
  }

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    _current.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = clock.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? DateTime(now.year + 1, now.month, now.day),
      firstDate: now,
      lastDate: DateTime(now.year + 20),
      locale: const Locale('pt', 'BR'),
      helpText: 'Prazo da meta',
    );
    if (picked != null) setState(() => _targetDate = picked);
  }

  Future<void> _submit() async {
    final draft = GoalDraft(
      id: widget.existing?.id,
      name: _name.text,
      target: parseAmountInput(_target.text) ?? double.nan,
      current: parseAmountInput(_current.text) ?? 0,
      targetDate: _targetDate,
    );
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
      appLogger.error('saveGoal', error, stack);
      if (mounted) {
        setState(() {
          _failure = FailureCopy.from(error, stack).short;
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetHeader(
              title: widget.existing == null ? 'Nova meta' : 'Editar meta',
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Nome',
                hintText: 'Reserva de emergência',
                prefixIcon: const Icon(Icons.flag_outlined),
                errorText: _errors.name,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _target,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Quanto quer juntar',
                hintText: '0,00',
                prefixText: 'R\$ ',
                prefixIcon: const Icon(Icons.savings_outlined),
                errorText: _errors.target,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _current,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Quanto já tem',
                hintText: '0,00',
                prefixText: 'R\$ ',
                prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                errorText: _errors.current,
              ),
            ),
            const SizedBox(height: 14),
            // The column has existed since the first migration and never
            // reached the app: without a date a goal is a number with no
            // deadline, and nothing can say whether it is on track.
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _pickDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Prazo',
                  prefixIcon: const Icon(Icons.event_rounded),
                  suffixIcon: _targetDate == null
                      ? null
                      : IconButton(
                          tooltip: 'Remover prazo',
                          onPressed: () => setState(() => _targetDate = null),
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
                child: Text(
                  _targetDate == null
                      ? 'Sem prazo'
                      : longDate.format(_targetDate!),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _targetDate == null
                        ? context.palette.inkSubtle
                        : context.palette.ink,
                  ),
                ),
              ),
            ),
            if (_failure != null) ...[
              const SizedBox(height: 14),
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
                            ? 'Criar meta'
                            : 'Salvar alterações',
                      ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
