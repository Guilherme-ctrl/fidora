import 'package:financeiro_ai/core/theme/theme.dart';
import 'package:financeiro_ai/features/transactions/domain/amount_input.dart';
import 'package:financeiro_ai/features/catalog/domain/catalog_drafts.dart';
import 'package:financeiro_ai/features/ledger/domain/entities/models.dart';
import 'package:financeiro_ai/core/design_system/ledger.dart';
import 'package:financeiro_ai/features/shared/widgets/failure_copy.dart';
import 'package:financeiro_ai/features/ledger/presenter/cubits/finance_cubit.dart';
import 'package:financeiro_ai/features/ledger/domain/repositories/repositories.dart';
import 'package:financeiro_ai/core/state/submission_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Opens the card editor and reloads the snapshot once something is saved.
Future<void> editCard(
  BuildContext context,
  {
  required List<Holder> holders,
  CreditCard? existing,
}) async {
  final saved = await showResponsiveSurface<bool>(
    context,
    builder: (context) => _CardForm(
      existing: existing,
      holders: holders,
      onSave: (draft) async {
        final catalog = context.read<CatalogRepository>();
        final finance = context.read<FinanceCubit>();
        await catalog.saveCard(draft);
        await finance.reloadAll();
      },
    ),
  );
  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          existing == null ? 'Cartão cadastrado.' : 'Cartão atualizado.',
        ),
        backgroundColor: context.palette.accent,
      ),
    );
  }
}

class _CardForm extends StatefulWidget {
  const _CardForm({required this.onSave, required this.holders, this.existing});
  final Future<void> Function(CardDraft draft) onSave;
  final List<Holder> holders;
  final CreditCard? existing;

  @override
  State<_CardForm> createState() => _CardFormState();
}

class _CardFormState extends State<_CardForm> {
  /// Owns the write while the sheet is open. Six forms hand-rolled
  /// this same busy-and-failure pair; this is the one copy.
  final _submission = SubmissionCubit();

  late final TextEditingController _name;
  late final TextEditingController _bank;
  late final TextEditingController _lastFour;
  late final TextEditingController _limit;
  String? _holderId;
  late int _closingDay;
  late int _dueDay;
  late bool _includeInTotals;
  CardDraftErrors _errors = const CardDraftErrors();

  @override
  void initState() {
    super.initState();
    final card = widget.existing;
    _name = TextEditingController(text: card?.name ?? '');
    _bank = TextEditingController(text: card?.bank ?? '');
    _lastFour = TextEditingController(text: card?.lastFour ?? '');
    _limit = TextEditingController(
      text: card == null
          ? ''
          : card.limit.toStringAsFixed(2).replaceAll('.', ','),
    );
    _holderId = card?.holderId;
    _closingDay = card?.closingDay ?? 1;
    _dueDay = card?.dueDay ?? 10;
    _includeInTotals = card?.includeInTotals ?? true;
  }

  @override
  void dispose() {
    _submission.close();
    for (final controller in [_name, _bank, _lastFour, _limit]) {
      controller.dispose();
    }
    super.dispose();
  }

  CardDraft _buildDraft() => CardDraft(
    id: widget.existing?.id,
    name: _name.text,
    bank: _bank.text,
    lastFour: _lastFour.text,
    closingDay: _closingDay,
    dueDay: _dueDay,
    limit: parseAmountInput(_limit.text) ?? 0,
    holderId: _holderId,
    holder:
        widget.holders
            .where((item) => item.id == _holderId)
            .firstOrNull
            ?.name ??
        '',
    includeInTotals: _includeInTotals,
  );

  Future<void> _submit() async {
    final draft = _buildDraft();
    final errors = draft.validate();
    setState(() => _errors = errors);
    _submission.reset();
    if (!errors.isEmpty) return;
    final ok = await _submission.run(
      'saveCard',
      () => widget.onSave(draft),
    );
    if (ok && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<SubmissionCubit, SubmissionState>(
    bloc: _submission,
    builder: (context, submission) =>
    SafeArea(
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
                        ? 'Novo cartão'
                        : 'Editar cartão',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'O final precisa bater com o que o Atalho envia — é por ele que '
                    'a captura encontra o cartão.',
                    style: TextStyle(color: context.palette.inkMuted),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Nome do cartão',
                      hintText: 'Uniclass Black',
                      prefixIcon: const Icon(Icons.credit_card_rounded),
                      errorText: _errors.name,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _bank,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Banco',
                      prefixIcon: const Icon(Icons.account_balance_rounded),
                      errorText: _errors.bank,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _lastFour,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Final',
                      counterText: '',
                      prefixIcon: const Icon(Icons.tag_rounded),
                      errorText: _errors.lastFour,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _DayField(
                          label: 'Fecha dia',
                          value: _closingDay,
                          error: _errors.closingDay,
                          onChanged: (value) => setState(() => _closingDay = value),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DayField(
                          label: 'Vence dia',
                          value: _dueDay,
                          error: _errors.dueDay,
                          onChanged: (value) => setState(() => _dueDay = value),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _limit,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Limite',
                      hintText: '0,00',
                      prefixText: 'R\$ ',
                      helperText:
                          'Opcional. Sem limite, o cartão não mostra barra de uso.',
                      prefixIcon: const Icon(Icons.speed_rounded),
                      errorText: _errors.limit,
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String?>(
                    initialValue: _holderId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Portador',
                      helperText: 'Opcional. Cadastre portadores em Mais.',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(child: Text('Sem portador')),
                      ...widget.holders.map(
                        (item) => DropdownMenuItem<String?>(
                          value: item.id,
                          child: Text(
                            item.includeInTotals
                                ? item.name
                                : '${item.name} — fora dos totais',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() => _holderId = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _includeInTotals,
                    onChanged: (value) => setState(() => _includeInTotals = value),
                    title: const Text(
                      'Somar nas minhas finanças',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'Desligue para um adicional cujos gastos não são seus.',
                    ),
                  ),
                  if (submission.failure != null) ...[
                    const SizedBox(height: 12),
                    _FailureBanner(message: FailureCopy.of(submission.failure!).short),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: submission.isBusy ? null : _submit,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      child: submission.isBusy
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              widget.existing == null
                                  ? 'Cadastrar cartão'
                                  : 'Salvar alterações',
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
  );
}

class _DayField extends StatelessWidget {
  const _DayField({
    required this.label,
    required this.value,
    required this.error,
    required this.onChanged,
  });
  final String label;
  final int value;
  final String? error;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<int>(
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: const Icon(Icons.event_rounded),
      errorText: error,
    ),
    items: List.generate(
      31,
      (index) =>
          DropdownMenuItem(value: index + 1, child: Text('${index + 1}')),
    ),
    onChanged: (selected) => onChanged(selected ?? value),
  );
}

class _FailureBanner extends StatelessWidget {
  const _FailureBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: context.palette.negative.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Icon(Icons.error_outline_rounded, color: context.palette.negative),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              color: context.palette.negative,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}
