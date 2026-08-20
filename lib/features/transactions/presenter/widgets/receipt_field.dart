import 'dart:typed_data';

import 'package:financeiro_ai/features/transactions/infra/receipt_recognizer.dart';
import 'package:financeiro_ai/core/theme/theme.dart';
import 'package:financeiro_ai/features/transactions/domain/receipt_scan.dart';
import 'package:financeiro_ai/core/design_system/common.dart';
import 'package:financeiro_ai/core/logging/logger.dart';
import 'package:financeiro_ai/features/ledger/domain/repositories/repositories.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:financeiro_ai/core/platform/file_access.dart';

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
class ReceiptField extends StatefulWidget {
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
  State<ReceiptField> createState() => _ReceiptFieldState();
}

class _ReceiptFieldState extends State<ReceiptField> {
  bool _busy = false;
  String? _failure;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final pending = widget.pending;
    final recognizer = context.read<ReceiptRecognizer>();

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
              onPressed: _busy ? null : () => _pick(ImageOrigin.camera),
              icon: const Icon(Icons.photo_camera_outlined, size: 18),
              label: const Text('Fotografar'),
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _pick(ImageOrigin.gallery),
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

  Future<void> _pick(ImageOrigin origin) async {
    final imageCapture = context.read<ImageCapture>();
    final recognizer = context.read<ReceiptRecognizer>();
    setState(() {
      _busy = true;
      _failure = null;
    });

    try {
      // Downscaling is the contract's default rather than an argument spelled
      // out here: it is a property of what a receipt needs, not of this widget.
      final picked = await imageCapture.pick(origin);
      if (picked == null) {
        if (mounted) setState(() => _busy = false);
        return;
      }

      final bytes = picked.bytes;
      ReceiptScan? scan;
      if (recognizer.isSupported) {
        // A failed reading must not lose the photograph: the attachment is
        // useful on its own, and recognition is the bonus.
        try {
          scan = await recognizer.scan(picked.path);
        } catch (error, stack) {
          // The photograph survives a failed reading on purpose — the
          // attachment is useful alone and recognition is the bonus — but the
          // cause is no longer thrown away with it.
          appLogger.error('receiptRecognizer.scan', error, stack);
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
    } catch (error, stack) {
      appLogger.error('receiptField.pick', error, stack);
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
///
/// A `StatefulWidget` holding one future rather than a provider family. The
/// family existed so two receipts on screen would not share a request and so
/// the short-lived link would be discarded; a future created once in
/// [initState] gives both, and does not leave a registration in the
/// presentation layer — which is where the old provider was declared, and
/// should not have been.
class _StoredReceipt extends StatefulWidget {
  const _StoredReceipt({required this.path});
  final String path;

  @override
  State<_StoredReceipt> createState() => _StoredReceiptState();
}

class _StoredReceiptState extends State<_StoredReceipt> {
  late Future<String> _url;

  @override
  void initState() {
    super.initState();
    _url = context.read<ReceiptStorage>().receiptUrl(widget.path);
  }

  @override
  void didUpdateWidget(_StoredReceipt old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) {
      _url = context.read<ReceiptStorage>().receiptUrl(widget.path);
    }
  }

  Widget _unavailable(BuildContext context) => Text(
    'Não foi possível carregar o comprovante.',
    style: TextStyle(color: context.palette.negative, fontSize: 12.5),
  );

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
    future: _url,
    builder: (context, snapshot) {
      if (snapshot.hasError) return _unavailable(context);
      final url = snapshot.data;
      if (url == null) {
        return const SizedBox(
          height: 160,
          child: Center(child: CircularProgressIndicator()),
        );
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          url,
          height: 160,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, _, _) => _unavailable(context),
        ),
      );
    },
  );
}
