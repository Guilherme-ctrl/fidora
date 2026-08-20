import 'package:clock/clock.dart';
import 'package:financeiro_ai/core/theme.dart';
import 'package:financeiro_ai/domain/amount_input.dart';
import 'package:financeiro_ai/domain/finance_rules.dart';
import 'package:financeiro_ai/domain/models.dart';
import 'package:financeiro_ai/domain/transaction_draft.dart';
import 'package:financeiro_ai/domain/receipt_scan.dart';
import 'package:financeiro_ai/presentation/widgets/common.dart';
import 'package:financeiro_ai/presentation/widgets/receipt_field.dart';
import 'package:financeiro_ai/presentation/widgets/ledger.dart';
import 'package:financeiro_ai/core/errors/failure.dart';
import 'package:financeiro_ai/core/logging/logger.dart';
import 'package:financeiro_ai/presentation/failure_copy.dart';
import 'package:financeiro_ai/presentation/category_visuals.dart';
import 'package:financeiro_ai/presentation/cubits/finance_cubit.dart';
import 'package:financeiro_ai/domain/repositories/repositories.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Opens the create/edit form. Resolves to true when a transaction was saved.
Future<bool?> showTransactionFormSheet(
  BuildContext context, {
  required FinanceSnapshot snapshot,
  required Future<void> Function(TransactionDraft draft) onSave,
  FinanceTransaction? existing,
}) => showResponsiveSurface<bool>(
  context,
  builder: (context) =>
      _TransactionForm(snapshot: snapshot, onSave: onSave, existing: existing),
);

class _TransactionForm extends StatefulWidget {
  const _TransactionForm({
    required this.snapshot,
    required this.onSave,
    this.existing,
  });

  final FinanceSnapshot snapshot;
  final Future<void> Function(TransactionDraft draft) onSave;
  final FinanceTransaction? existing;

  @override
  State<_TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends State<_TransactionForm> {
  late final TextEditingController _merchant;
  late final TextEditingController _amount;
  late final TextEditingController _installmentCurrent;
  late final TextEditingController _installmentTotal;
  late final TextEditingController _share;

  late DateTime _date;
  String? _categoryId;
  String? _cardId;
  bool _isIncome = false;
  bool _hasInstallments = false;
  bool _isShared = false;
  String? _holderId;
  String? _accountId;
  bool _saving = false;
  String? _failure;
  TransactionDraftErrors _errors = const TransactionDraftErrors();

  PendingReceipt? _pendingReceipt;

  /// Path of the receipt already stored, when editing. Cleared to null by
  /// removing it, which is what tells the save to detach.
  String? _receiptPath;

  /// Whether the person chose the date themselves. The field is never
  /// empty — it opens on today — so emptiness cannot decide whether a
  /// scanned date may replace it.
  bool _dateTouched = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _merchant = TextEditingController(text: existing?.merchant ?? '');
    _amount = TextEditingController(
      text: existing == null
          ? ''
          : existing.amount.toStringAsFixed(2).replaceAll('.', ','),
    );
    _installmentCurrent = TextEditingController(
      text: existing?.installmentCurrent?.toString() ?? '1',
    );
    _installmentTotal = TextEditingController(
      text: existing?.installmentTotal?.toString() ?? '2',
    );
    _share = TextEditingController(
      text: existing?.personalAmount == null
          ? ''
          : existing!.personalAmount!.toStringAsFixed(2).replaceAll('.', ','),
    );
    _isShared = existing?.isShared ?? false;
    _holderId = existing?.holderId;
    _accountId = existing?.accountId;
    _date = existing?.date ?? clock.now();
    _receiptPath = existing?.receiptPath;
    _hasInstallments = existing?.isInstallment ?? false;
    _isIncome = existing?.isIncome ?? false;
    _categoryId = widget.snapshot.categories
        .where((item) => item.name == existing?.category)
        .firstOrNull
        ?.id;
    _cardId = widget.snapshot.cards
        .where((item) => item.lastFour == existing?.cardLastFour)
        .firstOrNull
        ?.id;
  }

  @override
  void dispose() {
    _merchant.dispose();
    _amount.dispose();
    _installmentCurrent.dispose();
    _installmentTotal.dispose();
    _share.dispose();
    super.dispose();
  }

  CreditCard? get _selectedCard =>
      widget.snapshot.cards.where((item) => item.id == _cardId).firstOrNull;

  TransactionDraft _buildDraft({String? receiptPath}) => TransactionDraft(
    id: widget.existing?.id,
    purchasedAt: _date,
    merchant: _merchant.text,
    amount: parseAmountInput(_amount.text) ?? double.nan,
    categoryId: _categoryId ?? '',
    cardId: _isIncome ? null : _cardId,
    movementType: _isIncome ? 'credit' : 'purchase',
    installmentCurrent: _hasInstallments && !_isIncome
        ? int.tryParse(_installmentCurrent.text)
        : null,
    installmentTotal: _hasInstallments && !_isIncome
        ? int.tryParse(_installmentTotal.text)
        : null,
    holderId: _holderId,
    accountId: _cardId == null ? _accountId : null,
    personalAmount: _isShared && !_isIncome
        ? (parseAmountInput(_share.text) ?? double.nan)
        : null,
    receiptPath: receiptPath,
  );

  Future<void> _submit() async {
    final receipts = context.read<ReceiptStorage>();
    final errors = _buildDraft(receiptPath: _receiptPath).validate();
    setState(() {
      _errors = errors;
      _failure = null;
    });
    if (!errors.isEmpty) return;

    setState(() => _saving = true);
    try {
      // Uploaded before the row is written, so the transaction carries the
      // path in the same call. Writing the row first and attaching after
      // would leave a saved transaction with a lost receipt whenever the
      // second call failed.
      var path = _receiptPath;
      final pending = _pendingReceipt;
      if (pending != null) {
        path = await receipts
            .uploadReceipt(
              bytes: pending.bytes,
              fileName: pending.fileName,
              contentType: pending.contentType,
            );
      }
      await widget.onSave(_buildDraft(receiptPath: path));
      if (mounted) Navigator.of(context).pop(true);
    } on Failure catch (failure) {
      if (mounted) {
        setState(() {
          _failure = FailureCopy.of(failure).short;
          _saving = false;
        });
      }
    } catch (error, stack) {
      appLogger.error('saveTransaction', error, stack);
      if (mounted) {
        setState(() {
          _failure = FailureCopy.from(error, stack).short;
          _saving = false;
        });
      }
    }
  }

  /// Fills only what is still blank.
  ///
  /// Overwriting a typed value would make the recognizer authoritative over
  /// the person, and the recognizer is the one reading a photograph of a
  /// crumpled piece of paper.
  void _applyScan(ReceiptScan scan) {
    final filled = <String>[];
    setState(() {
      if (scan.merchant != null && _merchant.text.trim().isEmpty) {
        _merchant.text = scan.merchant!;
        filled.add('estabelecimento');
      }
      if (scan.amount != null && _amount.text.trim().isEmpty) {
        _amount.text = scan.amount!.toStringAsFixed(2).replaceAll('.', ',');
        filled.add('valor');
      }
      // The date always has a value — it defaults to today — so "empty" cannot
      // be the test. Only a date the person has not touched gives way.
      if (scan.date != null && !_dateTouched) {
        _date = scan.date!;
        filled.add('data');
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          filled.isEmpty
              ? 'Os campos já estavam preenchidos — nada foi alterado.'
              : 'Preenchi ${filled.join(', ')}. Confira antes de salvar.',
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: clock.now().add(const Duration(days: 365)),
      locale: const Locale('pt', 'BR'),
      helpText: 'Data da compra',
    );
    if (picked != null) {
      setState(() {
        _date = picked;
        _dateTouched = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = _selectedCard;
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
                SheetHeader(
                  title: widget.existing == null
                      ? 'Nova transação'
                      : 'Editar transação',
                ),
                const SizedBox(height: 20),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      label: Text('Saída'),
                      icon: Icon(Icons.south_east_rounded),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text('Entrada'),
                      icon: Icon(Icons.south_west_rounded),
                    ),
                  ],
                  selected: {_isIncome},
                  onSelectionChanged: (value) =>
                      setState(() => _isIncome = value.first),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _merchant,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: _isIncome ? 'Origem' : 'Estabelecimento',
                    prefixIcon: const Icon(Icons.storefront_outlined),
                    errorText: _errors.merchant,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Valor',
                    hintText: '0,00',
                    prefixText: 'R\$ ',
                    prefixIcon: const Icon(Icons.attach_money_rounded),
                    errorText: _errors.amount,
                  ),
                ),
                const SizedBox(height: 14),
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Data',
                      prefixIcon: Icon(Icons.event_rounded),
                    ),
                    child: Text(
                      longDate.format(_date),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
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
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: category.color,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  category.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _categoryId = value),
                ),
                if (!_isIncome) ...[
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String?>(
                    initialValue: _cardId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Forma de pagamento',
                      prefixIcon: Icon(Icons.credit_card_rounded),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        child: Text('Conta, Pix ou débito'),
                      ),
                      ...widget.snapshot.cards.map(
                        (item) => DropdownMenuItem<String?>(
                          value: item.id,
                          child: Text(
                            '${item.name} •• ${item.lastFour}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() => _cardId = value),
                  ),
                  if (card != null) _CompetenceHint(date: _date, card: card),
                  // Only meaningful without a card: an account movement has an
                  // origin, and without one the history shows it as "----".
                  if (card == null && widget.snapshot.accounts.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      initialValue: _accountId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Conta',
                        helperText: 'De onde saiu ou para onde entrou.',
                        prefixIcon: Icon(Icons.account_balance_rounded),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          child: Text('Não informar'),
                        ),
                        ...widget.snapshot.accounts.map(
                          (item) => DropdownMenuItem<String?>(
                            value: item.id,
                            child: Text(
                              item.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) => setState(() => _accountId = value),
                    ),
                  ],
                  const SizedBox(height: 4),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _hasInstallments,
                    onChanged: (value) =>
                        setState(() => _hasInstallments = value),
                    title: const Text(
                      'Compra parcelada',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (_hasInstallments)
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _installmentCurrent,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Parcela atual',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _installmentTotal,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'De'),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 4),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _isShared,
                    onChanged: (value) => setState(() => _isShared = value),
                    title: const Text(
                      'Dividir com alguém',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'O valor cheio continua na fatura; só a sua parte entra '
                      'nos totais.',
                    ),
                  ),
                  if (_isShared) ...[
                    TextField(
                      controller: _share,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Quanto é seu',
                        hintText: '0,00',
                        prefixText: 'R\$ ',
                        prefixIcon: const Icon(Icons.pie_chart_outline_rounded),
                        errorText: _errors.share,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    if (widget.snapshot.holders.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String?>(
                        initialValue: _holderId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'De quem é o resto',
                          helperText: 'Opcional, para saber com quem foi.',
                          prefixIcon: Icon(Icons.people_alt_outlined),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            child: Text('Não informar'),
                          ),
                          ...widget.snapshot.holders.map(
                            (item) => DropdownMenuItem<String?>(
                              value: item.id,
                              child: Text(item.name),
                            ),
                          ),
                        ],
                        onChanged: (value) => setState(() => _holderId = value),
                      ),
                    ],
                    _ShareSummary(
                      total: parseAmountInput(_amount.text),
                      mine: parseAmountInput(_share.text),
                    ),
                  ],
                  if (_errors.installment != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _errors.installment!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 22),
                ReceiptField(
                  existingPath: _receiptPath,
                  pending: _pendingReceipt,
                  onPicked: (receipt) =>
                      setState(() => _pendingReceipt = receipt),
                  onCleared: () => setState(() {
                    _pendingReceipt = null;
                    _receiptPath = null;
                  }),
                  onApplyScan: _applyScan,
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
                                ? 'Salvar transação'
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

/// Makes the invoice competence rule visible at the moment of entry, which is
/// the only moment the person can still correct the date.
class _CompetenceHint extends StatelessWidget {
  const _CompetenceHint({required this.date, required this.card});
  final DateTime date;
  final CreditCard card;

  @override
  Widget build(BuildContext context) {
    final competence = invoiceCompetence(date, card.closingDay);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: context.palette.accent,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Entra na fatura de ${monthYear.format(competence)} '
              '— o cartão fecha dia ${card.closingDay}.',
              style: TextStyle(
                color: context.palette.accent,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens the create/edit form and reloads the snapshot once something is saved.
/// Shared by the floating action button and the pages' header buttons so both
/// paths behave identically.
Future<void> createTransaction(
  BuildContext context,
  FinanceSnapshot snapshot, {
  FinanceTransaction? existing,
}) async {
  final saved = await showTransactionFormSheet(
    context,
    snapshot: snapshot,
    existing: existing,
    onSave: (draft) async {
      final transactions = context.read<TransactionRepository>();
      final finance = context.read<FinanceCubit>();
      await transactions.saveTransaction(draft);
      await finance.reloadLedger();
    },
  );
  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          existing == null ? 'Transação salva.' : 'Transação atualizada.',
        ),
        backgroundColor: context.palette.accent,
      ),
    );
  }
}

/// Says the other half out loud. Typing "my share" and being told what is left
/// is what makes the split obviously right or obviously wrong.
class _ShareSummary extends StatelessWidget {
  const _ShareSummary({required this.total, required this.mine});
  final double? total;
  final double? mine;

  @override
  Widget build(BuildContext context) {
    if (total == null || mine == null || mine! > total!) {
      return const SizedBox.shrink();
    }
    final others = total! - mine!;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: context.palette.accent,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              others <= 0
                  ? 'A compra inteira entra como sua.'
                  : '${currency.format(others)} ficam de fora dos seus totais; '
                        'a fatura segue com ${currency.format(total)}.',
              style: TextStyle(
                color: context.palette.accent,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
