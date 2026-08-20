import 'dart:typed_data';

/// A file the person chose, or one the app is handing back to them.
///
/// Deliberately not `XFile`. That type belongs to `cross_file` and arrives
/// through three different plugins; naming it in a contract would mean every
/// caller keeps a plugin in its import list, which is the coupling these
/// interfaces exist to remove.
class PickedFile {
  const PickedFile({
    required this.name,
    required this.bytes,
    this.path = '',
    this.mimeType,
  });

  final String name;
  final Uint8List bytes;

  /// Where the file sits on disk. Empty on the web, which has no such place.
  /// Only the receipt reader needs it — the native text recogniser takes a
  /// path, not bytes.
  final String path;

  final String? mimeType;
}

/// One accepted kind of file, in the terms every platform asks for.
///
/// macOS wants uniform type identifiers, the web wants MIME types, and the
/// rest want extensions. A picker that only knew one of the three silently
/// accepted nothing on the platforms that wanted another.
class FileTypeFilter {
  const FileTypeFilter({
    required this.label,
    this.extensions = const [],
    this.mimeTypes = const [],
    this.uniformTypeIdentifiers = const [],
  });

  final String label;
  final List<String> extensions;
  final List<String> mimeTypes;
  final List<String> uniformTypeIdentifiers;
}

/// Asks the person for a file.
abstract interface class FilePicker {
  /// Returns null when the person cancelled, which is not a failure.
  Future<PickedFile?> pickFile({required List<FileTypeFilter> accept});
}

/// Where an image comes from.
enum ImageOrigin { camera, gallery }

/// Asks the person for a photograph.
abstract interface class ImageCapture {
  /// Whether this build can offer [origin] at all.
  bool supports(ImageOrigin origin);

  /// [maxWidth] and [quality] are applied before the bytes are ever read: a
  /// full-resolution phone photo is several times the receipt bucket's limit,
  /// and downscaling costs nothing that text recognition needs.
  Future<PickedFile?> pick(
    ImageOrigin origin, {
    int maxWidth = 2000,
    int quality = 85,
  });
}

/// Hands a file to the operating system's share sheet.
abstract interface class ShareService {
  Future<void> shareFile({
    required Uint8List bytes,
    required String name,
    required String mimeType,
  });
}
