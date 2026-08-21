import 'package:clock/clock.dart';
import 'package:financeiro_ai/core/theme/theme.dart';
import 'package:financeiro_ai/features/transactions/domain/amount_input.dart';
import 'package:financeiro_ai/features/catalog/domain/catalog_drafts.dart';
import 'package:financeiro_ai/features/ledger/domain/entities/models.dart';
import 'package:financeiro_ai/core/design_system/common.dart';
import 'package:financeiro_ai/core/design_system/ledger.dart';
import 'package:financeiro_ai/features/shared/widgets/failure_copy.dart';
import 'package:financeiro_ai/features/ledger/presenter/cubits/finance_cubit.dart';
import 'package:financeiro_ai/features/ledger/domain/repositories/repositories.dart';
import 'package:financeiro_ai/core/state/submission_cubit.dart';
import 'package:financeiro_ai/core/design_system/loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

Future<void> editGoal(BuildContext context, {Goal? existing}) async {
  final saved = await showResponsiveSurface<bool>(
    context,
    builder: (context) => _GoalForm(
      existing: existing,
      onSave: (draft) async {
        final catalog = context.read<CatalogRepository>();
        final finance = context.read<FinanceCubit>();
        await catalog.saveGoal(draft);
        await finance.reloadAll();
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
  /// Owns the write while the sheet is open. Six forms hand-rolled
  /// this same busy-and-failure pair; this is the one copy.
  final _submission = SubmissionCubit();

  late final TextEditingController _name;
  late final TextEditingController _target;
  late final TextEditingController _current;
  DateTime? _targetDate;
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
    _submission.close();
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
    setState(() => _errors = errors);
    _submission.reset();
    if (!errors.isEmpty) return;
    final ok = await _submission.run('saveGoal', () => widget.onSave(draft));
    if (ok && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<SubmissionCubit, SubmissionState>(
    bloc: _submission,
    builder: (context, submission) => SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
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
              if (submission.failure != null) ...[
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
                          FailureCopy.of(submission.failure!).short,
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
                onPressed: submission.isBusy ? null : _submit,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  child: submission.isBusy
                      ? const BusySpinner(size: 20)
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
    ),
  );
}
