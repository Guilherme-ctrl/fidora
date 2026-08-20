import 'package:financeiro_ai/domain/receipt_scan.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Reads text off a photographed receipt.
///
/// An interface rather than a direct plugin call so the form can be driven in
/// tests without a camera, and so the web build has something to return that
/// is not an exception.
abstract class ReceiptRecognizer {
  /// Whether this build can read a receipt at all. False on the web, where the
  /// recognizer has no implementation — the image can still be attached.
  bool get isSupported;

  Future<ReceiptScan> scan(String imagePath);

  /// Releases the native recognizer. Not optional on iOS: the ML Kit instance
  /// holds a model in memory until it is closed.
  Future<void> dispose();
}

/// On-device recognition. The photograph never leaves the phone, which for a
/// document carrying a merchant, an amount and a date is the point.
class MlKitReceiptRecognizer implements ReceiptRecognizer {
  TextRecognizer? _recognizer;

  @override
  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  @override
  Future<ReceiptScan> scan(String imagePath) async {
    if (!isSupported) return const ReceiptScan.empty();
    final recognizer = _recognizer ??= TextRecognizer();
    final recognized = await recognizer.processImage(
      InputImage.fromFilePath(imagePath),
    );
    return parseReceipt(recognized.text);
  }

  @override
  Future<void> dispose() async {
    await _recognizer?.close();
    _recognizer = null;
  }
}

/// Stands in where recognition cannot run — the web build, and any test that
/// only cares about attaching the image.
class UnavailableReceiptRecognizer implements ReceiptRecognizer {
  const UnavailableReceiptRecognizer();

  @override
  bool get isSupported => false;

  @override
  Future<ReceiptScan> scan(String imagePath) async => const ReceiptScan.empty();

  @override
  Future<void> dispose() async {}
}

/// The recognizer this build can actually use.
///
/// Composed once, at start-up, so the native model is loaded once rather than
/// per photograph. On the web and anywhere ML Kit has no implementation this
/// is the unavailable one, which returns an empty reading instead of throwing
/// — the photograph is still worth attaching.
ReceiptRecognizer defaultReceiptRecognizer() {
  final recognizer = MlKitReceiptRecognizer();
  return recognizer.isSupported
      ? recognizer
      : const UnavailableReceiptRecognizer();
}
