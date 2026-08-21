import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads the bundled fonts before any test runs.
///
/// The test environment ships a font whose every glyph is a rectangle, which is
/// why the reference images taken in PR 0 recorded layout, spacing and colour
/// but not a single letterform. That was named as a known limit at the time,
/// with the note that it would lift once the fonts were bundled. They are, so
/// it lifts: the goldens now record the typography too, which is where a good
/// part of this design system lives.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  const families = {'Sora': 'assets/fonts/Sora.ttf'};

  for (final entry in families.entries) {
    final file = File(entry.value);
    if (!file.existsSync()) continue;
    final loader = FontLoader(
      entry.key,
    )..addFont(file.readAsBytes().then((bytes) => ByteData.view(bytes.buffer)));
    await loader.load();
  }

  await testMain();
}
