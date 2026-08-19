import 'dart:typed_data';

import 'package:financeiro_ai/application/providers.dart';
import 'package:financeiro_ai/application/receipt_recognizer.dart';
import 'package:financeiro_ai/core/theme.dart';
import 'package:financeiro_ai/domain/receipt_scan.dart';
import 'package:financeiro_ai/presentation/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// A receipt picked but not yet stored.
class PendingReceipt {
  const PendingReceipt({
    required this.bytes,
    required this.fileName,
    required this.contentType,
    this.scan,
  });

  final Uint8List bytes;
  final String fileName;
  final String contentType;

  /// What the recognizer read, when it could run.
  final ReceiptScan? scan;
}

/// Attach, read and detach a receipt inside the transaction form.
///
/// What it reads is offered, never applied: the form does not silently change a
/// figure the person typed. A wrong amount that arrives prefilled gets
/// confirmed along with everything else, and then it is a fact in the ledger.
class ReceiptField extends ConsumerStatefulWidget {
  const ReceiptField({
    super.key,
    required this.existingPath,
    required this.pending,
    required this.onPicked,
    required this.onCleared,
    required this.onApplyScan,
  });

  /// Path of a receipt already stored, when editing.
  final String? existingPath;

  final PendingReceipt? pending;
  final ValueChanged<PendingReceipt> onPicked;
  final VoidCallback onCleared;

  /// Called when the person accepts what was read. The form decides which
  /// fields it is willing to overwrite.
  final ValueChanged<ReceiptScan> onApplyScan;

  @override
  ConsumerState<ReceiptField> createState() => _ReceiptFieldState();
}

class _ReceiptFieldState extends ConsumerState<ReceiptField> {
  bool _busy = false;
  String? _failure;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final pending = widget.pending;
    final recognizer = ref.read(receiptRecognizerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Comprovante',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        if (pending == null && widget.existingPath == null)
          Text(
            recognizer.isSupported
                ? 'Fotografe a nota e o Finora lê o valor, o estabelecimento e '
                      'a data. Você confere antes de qualquer coisa ser '
                      'preenchida.'
                : 'Anexe a foto da nota. A leitura automática só funciona no '
                      'aplicativo do celular.',
            style: TextStyle(
              color: palette.inkMuted,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
        if (pending != null) ...[
          _Preview(bytes: pending.bytes),
          const SizedBox(height: 10),
          _ScanSummary(
            scan: pending.scan,
            recognizerAvailable: recognizer.isSupported,
            onApply: () => widget.onApplyScan(pending.scan!),
          ),
        ] else if (widget.existingPath != null)
          _StoredReceipt(path: widget.existingPath!),
        if (_failure != null) ...[
          const SizedBox(height: 8),
          Text(
            _failure!,
            style: TextStyle(color: palette.negative, fontSize: 12.5),
          ),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _pick(ImageSource.camera),
              icon: const Icon(Icons.photo_camera_outlined, size: 18),
              label: const Text('Fotografar'),
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _pick(ImageSource.gallery),
              icon: const Icon(Icons.image_outlined, size: 18),
              label: const Text('Escolher imagem'),
            ),
            if (pending != null || widget.existingPath != null)
              TextButton.icon(
                onPressed: _busy ? null : widget.onCleared,
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text('Remover'),
              ),
          ],
        ),
        if (_busy) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
              Text(
                'Lendo a nota…',
                style: TextStyle(color: palette.inkMuted, fontSize: 12.5),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _pick(ImageSource source) async {
    setState(() {
      _busy = true;
      _failure = null;
    });

    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        // Capped before the bytes are ever read: a full-resolution phone photo
        // is several times the bucket's limit, and downscaling here costs
        // nothing that text recognition needs.
        maxWidth: 2000,
        imageQuality: 85,
      );
      if (picked == null) {
        if (mounted) setState(() => _busy = false);
        return;
      }

      final bytes = await picked.readAsBytes();
      final recognizer = ref.read(receiptRecognizerProvider);
      ReceiptScan? scan;
      if (recognizer.isSupported) {
        // A failed reading must not lose the photograph: the attachment is
        // useful on its own, and recognition is the bonus.
        try {
          scan = await recognizer.scan(picked.path);
        } catch (_) {
          scan = null;
        }
      }

      if (!mounted) return;
      setState(() => _busy = false);
      widget.onPicked(
        PendingReceipt(
          bytes: bytes,
          fileName: picked.name,
          contentType: picked.mimeType ?? 'image/jpeg',
          scan: scan,
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _failure = 'Não foi possível abrir a imagem.';
        });
      }
    }
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.bytes});
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: Image.memory(
      bytes,
      height: 160,
      width: double.infinity,
      fit: BoxFit.cover,
    ),
  );
}

/// What the recognizer read, offered rather than applied.
class _ScanSummary extends StatelessWidget {
  const _ScanSummary({
    required this.scan,
    required this.recognizerAvailable,
    required this.onApply,
  });

  final ReceiptScan? scan;
  final bool recognizerAvailable;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    if (!recognizerAvailable) {
      return Text(
        'A imagem será anexada ao lançamento. A leitura automática só '
        'funciona no aplicativo do celular.',
        style: TextStyle(color: palette.inkSubtle, fontSize: 12.5, height: 1.4),
      );
    }

    final reading = scan;
    if (reading == null || !reading.hasAnything) {
      return Text(
        'Não consegui ler nada desta foto. A imagem fica anexada mesmo assim '
        '— preencha os campos à mão.',
        style: TextStyle(color: palette.inkSubtle, fontSize: 12.5, height: 1.4),
      );
    }

    final parts = <String>[
      if (reading.merchant != null) reading.merchant!,
      if (reading.amount != null) currency.format(reading.amount!),
      if (reading.date != null)
        '${reading.date!.day.toString().padLeft(2, '0')}/'
            '${reading.date!.month.toString().padLeft(2, '0')}/'
            '${reading.date!.year}',
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.accentSoft.withValues(alpha: .5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Li na nota: ${parts.join(' · ')}',
            style: TextStyle(
              color: palette.accent,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonal(
              onPressed: onApply,
              // Explicit about what it touches: the button fills blanks and
              // leaves anything already typed alone.
              child: const Text('Preencher os campos vazios'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows a receipt already in storage, fetched through a signed URL.
class _StoredReceipt extends ConsumerWidget {
  const _StoredReceipt({required this.path});
  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(receiptUrlProvider(path));

    return url.when(
      loading: () => const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Text(
        'Não foi possível carregar o comprovante.',
        style: TextStyle(color: context.palette.negative, fontSize: 12.5),
      ),
      data: (value) => ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          value,
          height: 160,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, _, _) => Text(
            'Não foi possível carregar o comprovante.',
            style: TextStyle(color: context.palette.negative, fontSize: 12.5),
          ),
        ),
      ),
    );
  }
}

/// A signed URL for one stored receipt. Family-keyed so two receipts on screen
/// do not share one request, and auto-disposed because the link is short-lived.
final receiptUrlProvider = FutureProvider.autoDispose.family<String, String>(
  (ref, path) => ref.watch(financeRepositoryProvider).receiptUrl(path),
);
