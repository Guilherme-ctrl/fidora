import 'dart:convert';

import 'package:financeiro_ai/application/providers.dart';
import 'package:financeiro_ai/core/theme.dart';
import 'package:financeiro_ai/domain/csv_export.dart';
import 'package:financeiro_ai/domain/models.dart';
import 'package:financeiro_ai/presentation/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// Export and import history in one place: both answer "what is in here, and
/// how do I get it out".
class DataPage extends ConsumerWidget {
  const DataPage({super.key, required this.snapshot});
  final FinanceSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batches = ref.watch(importBatchesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Seus dados')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(importBatchesProvider);
          await ref.read(importBatchesProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Exportar',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Um arquivo CSV com os ${snapshot.transactions.length} '
                      'lançamentos carregados. Separado por ponto e vírgula e '
                      'com vírgula decimal, que é o que o Excel e o Planilhas '
                      'esperam em português.',
                      style: TextStyle(
                        color: context.palette.inkMuted,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: snapshot.transactions.isEmpty
                          ? null
                          : () => _export(context),
                      icon: const Icon(Icons.ios_share_rounded),
                      label: const Text('Exportar CSV'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Importações',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            batches.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => _Message(
                text: 'Não foi possível carregar o histórico de importações.',
                color: context.palette.danger,
              ),
              data: (items) => items.isEmpty
                  ? _Message(
                      text:
                          'Nenhuma importação registrada. Cada fatura importada '
                          'aparece aqui com o que ela produziu.',
                      color: context.palette.inkMuted,
                    )
                  : Column(
                      // Without this the cards shrink to their content and sit
                      // centred, while the export card above spans the width.
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ...items.map((item) => _BatchTile(batch: item)),
                        const SizedBox(height: 12),
                        // Being explicit beats a button that guesses: without a
                        // link from each row to its batch, an undo would have to
                        // match on a file name and could delete the wrong rows.
                        Text(
                          'Desfazer uma importação ainda não é possível: os '
                          'lançamentos não guardam a qual lote pertencem, e '
                          'apagar por nome de arquivo poderia atingir linhas '
                          'erradas.',
                          style: TextStyle(
                            color: context.palette.inkSubtle,
                            fontSize: 12.5,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _export(BuildContext context) async {
    final csv = buildTransactionsCsv(snapshot, snapshot.transactions);
    final file = XFile.fromData(
      utf8.encode(csv),
      mimeType: 'text/csv',
      name: csvFileName(DateTime.now()),
    );
    try {
      await SharePlus.instance.share(
        ShareParams(files: [file], fileNameOverrides: [file.name]),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Não foi possível abrir o compartilhamento.'),
            backgroundColor: context.palette.danger,
          ),
        );
      }
    }
  }
}

class _BatchTile extends StatelessWidget {
  const _BatchTile({required this.batch});
  final ImportBatch batch;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            batch.fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5),
          ),
          const SizedBox(height: 4),
          Text(
            longDate.format(batch.createdAt),
            style: TextStyle(color: context.palette.inkMuted, fontSize: 12.5),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Count(label: 'lidos', value: batch.rowsRead),
              _Count(label: 'criados', value: batch.rowsCreated),
              if (batch.rowsUpdated > 0)
                _Count(label: 'conciliados', value: batch.rowsUpdated),
              if (batch.rowsDuplicated > 0)
                _Count(label: 'duplicados', value: batch.rowsDuplicated),
              if (batch.rowsToReview > 0)
                _Count(
                  label: 'para revisão',
                  value: batch.rowsToReview,
                  highlight: true,
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _Count extends StatelessWidget {
  const _Count({
    required this.label,
    required this.value,
    this.highlight = false,
  });
  final String label;
  final int value;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: highlight
          ? context.palette.warning.withValues(alpha: .18)
          : context.palette.canvas,
      borderRadius: BorderRadius.circular(9),
    ),
    child: Text(
      '$value $label',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: highlight ? context.palette.onWarning : context.palette.inkMuted,
      ),
    ),
  );
}

class _Message extends StatelessWidget {
  const _Message({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(text, style: TextStyle(color: color, height: 1.45)),
  );
}
