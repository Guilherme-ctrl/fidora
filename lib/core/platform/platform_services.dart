/// The real implementations, over the plugins.
///
/// Three call sites used to instantiate these directly inside widgets —
/// `ImagePicker()` in the receipt field, `openFile()` in the settings page,
/// `SharePlus.instance` in the data page — which made all three untestable and
/// put plugin imports in the presentation layer. The pattern was already
/// proven in the same file as one of them: receipt *recognition* was behind an
/// interface while receipt *picking* was not.
library;

import 'package:file_selector/file_selector.dart' as selector;
import 'package:financeiro_ai/core/platform/file_access.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart' as picker;
import 'package:share_plus/share_plus.dart' as share;


class SystemFilePicker implements FilePicker {
  const SystemFilePicker();

  @override
  Future<PickedFile?> pickFile({
    required List<FileTypeFilter> accept,
  }) async {
    final picked = await selector.openFile(
      acceptedTypeGroups: [
        for (final filter in accept)
          selector.XTypeGroup(
            label: filter.label,
            extensions: filter.extensions,
            mimeTypes: filter.mimeTypes.isEmpty ? null : filter.mimeTypes,
            uniformTypeIdentifiers: filter.uniformTypeIdentifiers.isEmpty
                ? null
                : filter.uniformTypeIdentifiers,
          ),
      ],
    );
    if (picked == null) return null;
    return PickedFile(
      name: picked.name,
      bytes: await picked.readAsBytes(),
      path: picked.path,
      mimeType: picked.mimeType,
    );
  }
}

class SystemImageCapture implements ImageCapture {
  const SystemImageCapture();

  /// The web can offer a file chooser for the gallery but has no camera here.
  @override
  bool supports(ImageOrigin origin) =>
      origin == ImageOrigin.gallery || !kIsWeb;

  @override
  Future<PickedFile?> pick(
    ImageOrigin origin, {
    int maxWidth = 2000,
    int quality = 85,
  }) async {
    final picked = await picker.ImagePicker().pickImage(
      source: origin == ImageOrigin.camera
          ? picker.ImageSource.camera
          : picker.ImageSource.gallery,
      maxWidth: maxWidth.toDouble(),
      imageQuality: quality,
    );
    if (picked == null) return null;
    return PickedFile(
      name: picked.name,
      bytes: await picked.readAsBytes(),
      path: picked.path,
      mimeType: picked.mimeType,
    );
  }
}

class SystemShareService implements ShareService {
  const SystemShareService();

  @override
  Future<void> shareFile({
    required Uint8List bytes,
    required String name,
    required String mimeType,
  }) async {
    final file = share.XFile.fromData(bytes, mimeType: mimeType, name: name);
    await share.SharePlus.instance.share(
      share.ShareParams(files: [file], fileNameOverrides: [name]),
    );
  }
}
