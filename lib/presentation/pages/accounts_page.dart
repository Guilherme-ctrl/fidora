import 'package:financeiro_ai/application/providers.dart';
import 'package:financeiro_ai/core/theme.dart';
import 'package:financeiro_ai/domain/amount_input.dart';
import 'package:financeiro_ai/domain/catalog_drafts.dart';
import 'package:financeiro_ai/domain/insights.dart';
import 'package:financeiro_ai/domain/models.dart';
import 'package:financeiro_ai/domain/transaction_draft.dart';
import 'package:financeiro_ai/presentation/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AccountsPage extends ConsumerWidget {
  const AccountsPage({super.key, required this.snapshot});
  final FinanceSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balances = accountBalances(snapshot);
    final total = totalAccountBalance(balances);

    return Scaffold(
      appBar: AppBar(title: const Text('Contas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => editAccount(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nova conta'),
      ),
      body: balances.isEmpty
          ? const _Empty()
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 96),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currency.format(total),
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'somando ${balances.length} ${balances.length == 1 ? 'conta' : 'contas'}',
                          style: TextStyle(color: context.palette.inkMuted),
                        ),
                        const SizedBox(height: 12),
                        // Cards are debt, not something you hold; mixing them in
                        // would turn this into a number that means nothing.
                        Text(
                          'Cartões de crédito não entram: são dívida, não saldo.',
                          style: TextStyle(
                            color: context.palette.inkSubtle,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                ...balances.map(
                  (item) => _AccountTile(
                    balance: item,
                    onEdit: () =>
                        editAccount(context, ref, existing: item.account),
                    onArchive: () => _archive(context, ref, item),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _archive(
    BuildContext context,
    WidgetRef ref,
    AccountBalance item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Arquivar conta?'),
        content: Text(
          '“${item.account.name}” sai das listas e do total. Os '
          '${item.entries} lançamentos ligados a ela continuam no histórico.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.palette.danger,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Arquivar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(financeRepositoryProvider)
          .setAccountActive(item.account.id, active: false);
      await refreshFinanceSnapshot(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Conta arquivada.'),
            backgroundColor: context.palette.brand,
          ),
        );
      }
    } on FinanceWriteException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message),
            backgroundColor: context.palette.danger,
          ),
        );
      }
    }
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.balance,
    required this.onEdit,
    required this.onArchive,
  });
  final AccountBalance balance;
  final VoidCallback onEdit;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final negative = balance.balance < 0;
    return Card(
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
                          balance.account.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15.5,
                          ),
                        ),
                      ),
                      if (!balance.account.includeInTotals) ...[
                        const SizedBox(width: 8),
                        Chip(
                          label: const Text(
                            'Fora do total',
                            style: TextStyle(fontSize: 11),
                          ),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: context.palette.warning.withValues(
                            alpha: .18,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      balance.account.typeLabel,
                      if (balance.account.bank.isNotEmpty) balance.account.bank,
                      '${balance.entries} ${balance.entries == 1 ? 'lançamento' : 'lançamentos'}',
                    ].join(' • '),
                    style: TextStyle(
                      color: context.palette.inkMuted,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  currency.format(balance.balance),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: negative ? context.palette.danger : null,
                  ),
                ),
                // Saying which number this is matters: with no opening balance
                // it is the movement so far, not what the account holds.
                if (balance.isMovementOnly)
                  Text(
                    'movimento',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.palette.inkSubtle,
                    ),
                  ),
              ],
            ),
            IconButton(
              tooltip: 'Editar',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Arquivar',
              onPressed: onArchive,
              icon: Icon(Icons.archive_outlined, color: context.palette.danger),
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(28, 80, 28, 24),
    children: [
      Icon(
        Icons.account_balance_rounded,
        size: 50,
        color: context.palette.brand,
      ),
      const SizedBox(height: 18),
      const Text(
        'Nenhuma conta ainda',
        textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19),
      ),
      const SizedBox(height: 8),
      Text(
        'Cadastre onde o dinheiro fica: conta corrente, poupança, carteira. '
        'Sem isso, tudo que não é cartão aparece sem origem no histórico.',
        textAlign: TextAlign.center,
        style: TextStyle(color: context.palette.inkMuted, height: 1.45),
      ),
    ],
  );
}

Future<void> editAccount(
  BuildContext context,
  WidgetRef ref, {
  Account? existing,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _AccountForm(
      existing: existing,
      onSave: (draft) async {
        await ref.read(financeRepositoryProvider).saveAccount(draft);
        await refreshFinanceSnapshot(ref);
      },
    ),
  );
  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          existing == null ? 'Conta cadastrada.' : 'Conta atualizada.',
        ),
        backgroundColor: context.palette.brand,
      ),
    );
  }
}

class _AccountForm extends StatefulWidget {
  const _AccountForm({required this.onSave, this.existing});
  final Future<void> Function(AccountDraft draft) onSave;
  final Account? existing;

  @override
  State<_AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends State<_AccountForm> {
  late final TextEditingController _name;
  late final TextEditingController _bank;
  late final TextEditingController _opening;
  late String _type;
  late bool _includeInTotals;
  bool _saving = false;
  String? _failure;
  AccountDraftErrors _errors = const AccountDraftErrors();

  @override
  void initState() {
    super.initState();
    final account = widget.existing;
    _name = TextEditingController(text: account?.name ?? '');
    _bank = TextEditingController(text: account?.bank ?? '');
    _opening = TextEditingController(
      text: account == null || account.openingBalance == 0
          ? ''
          : account.openingBalance.toStringAsFixed(2).replaceAll('.', ','),
    );
    _type = account?.type ?? 'checking';
    _includeInTotals = account?.includeInTotals ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _bank.dispose();
    _opening.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final draft = AccountDraft(
      id: widget.existing?.id,
      name: _name.text,
      bank: _bank.text,
      type: _type,
      openingBalance: parseAmountInput(_opening.text) ?? 0,
      includeInTotals: _includeInTotals,
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existing == null ? 'Nova conta' : 'Editar conta',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Nome',
                hintText: 'Conta corrente',
                prefixIcon: const Icon(Icons.account_balance_rounded),
                errorText: _errors.name,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _bank,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Banco',
                helperText: 'Opcional.',
                prefixIcon: Icon(Icons.business_rounded),
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _type,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Tipo',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: accountTypes.entries
                  .map(
                    (entry) => DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _type = value ?? _type),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _opening,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: InputDecoration(
                labelText: 'Saldo antes do histórico',
                hintText: '0,00',
                prefixText: 'R\$ ',
                helperText:
                    'Sem isso, o número mostrado é só a soma das movimentações.',
                prefixIcon: const Icon(Icons.savings_outlined),
                errorText: _errors.openingBalance,
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _includeInTotals,
              onChanged: (value) => setState(() => _includeInTotals = value),
              title: const Text(
                'Somar no total',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (_failure != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.palette.danger.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: context.palette.danger,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _failure!,
                        style: TextStyle(
                          color: context.palette.danger,
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
                            ? 'Cadastrar conta'
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
