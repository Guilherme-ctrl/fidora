import 'package:financeiro_ai/application/providers.dart';
import 'package:financeiro_ai/core/theme.dart';
import 'package:financeiro_ai/domain/catalog_drafts.dart';
import 'package:financeiro_ai/domain/models.dart';
import 'package:financeiro_ai/presentation/widgets/ledger.dart';
import 'package:financeiro_ai/core/errors/failure.dart';
import 'package:financeiro_ai/presentation/failure_copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HoldersPage extends ConsumerWidget {
  const HoldersPage({super.key, required this.snapshot});
  final FinanceSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final holders = snapshot.holders;
    return Scaffold(
      appBar: AppBar(title: const Text('Portadores')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref),
        icon: const Icon(Icons.person_add_alt_rounded),
        label: const Text('Novo portador'),
      ),
      body: holders.isEmpty
          ? _Empty(onCreate: () => _edit(context, ref))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 96),
              itemCount: holders.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      'Desligue “somar nas minhas finanças” para um portador '
                      'cujos gastos não são seus. Os cartões atribuídos a ele '
                      'saem dos totais e dos gráficos, mas continuam no histórico.',
                      style: TextStyle(color: context.palette.inkMuted),
                    ),
                  );
                }
                final holder = holders[index - 1];
                return _HolderTile(
                  holder: holder,
                  cards: snapshot.cards
                      .where((card) => card.holderId == holder.id)
                      .length,
                  onEdit: () => _edit(context, ref, existing: holder),
                  onDelete: () => _delete(context, ref, holder),
                );
              },
            ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, {
    Holder? existing,
  }) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    var include = existing?.includeInTotals ?? true;

    final draft = await showResponsiveSurface<HolderDraft>(
      context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    existing == null ? 'Novo portador' : 'Editar portador',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nome',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: include,
                    onChanged: (value) => setSheetState(() => include = value),
                    title: const Text(
                      'Somar nas minhas finanças',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(
                      HolderDraft(
                        id: existing?.id,
                        name: nameController.text,
                        includeInTotals: include,
                      ),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 13),
                      child: Text('Salvar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (draft == null || !context.mounted) return;

    try {
      await ref.read(catalogRepositoryProvider).saveHolder(draft);
      await refreshFinanceSnapshot(ref);
      if (context.mounted) _toast(context, 'Portador salvo.');
    } on Failure catch (failure) {
      if (context.mounted) _toast(context, FailureCopy.of(failure).short, error: true);
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Holder holder,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir portador?'),
        content: Text(
          'Os cartões de “${holder.name}” continuam cadastrados e ficam sem '
          'portador. Nenhum lançamento é perdido.',
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
      await ref.read(catalogRepositoryProvider).deleteHolder(holder.id);
      await refreshFinanceSnapshot(ref);
      if (context.mounted) _toast(context, 'Portador excluído.');
    } on Failure catch (failure) {
      if (context.mounted) _toast(context, FailureCopy.of(failure).short, error: true);
    }
  }

  void _toast(BuildContext context, String message, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error
              ? context.palette.negative
              : context.palette.income,
        ),
      );
}

class _HolderTile extends StatelessWidget {
  const _HolderTile({
    required this.holder,
    required this.cards,
    required this.onEdit,
    required this.onDelete,
  });
  final Holder holder;
  final int cards;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
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
                        holder.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15.5,
                        ),
                      ),
                    ),
                    if (!holder.includeInTotals) ...[
                      const SizedBox(width: 8),
                      Chip(
                        label: const Text(
                          'Fora dos totais',
                          style: TextStyle(fontSize: 11),
                        ),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: context.palette.pending.withValues(
                          alpha: .18,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  cards == 0
                      ? 'Nenhum cartão atribuído'
                      : '$cards ${cards == 1 ? 'cartão' : 'cartões'}',
                  style: TextStyle(
                    color: context.palette.inkMuted,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Editar',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Excluir',
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

class _Empty extends StatelessWidget {
  const _Empty({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(28, 80, 28, 24),
    children: [
      Icon(Icons.people_alt_rounded, size: 50, color: context.palette.accent),
      const SizedBox(height: 18),
      const Text(
        'Nenhum portador ainda',
        textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19),
      ),
      const SizedBox(height: 8),
      Text(
        'Portadores servem para cartões adicionais. Marcando um portador como '
        'fora dos totais, os gastos dos cartões dele deixam de contar como seus.',
        textAlign: TextAlign.center,
        style: TextStyle(color: context.palette.inkMuted, height: 1.45),
      ),
    ],
  );
}
