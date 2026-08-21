// Renders the app icons from the same painter the app draws with.
//
// The mark is a `CustomPainter`, not an asset, so the icon does not need a
// design tool in the loop: this walks the sizes iOS and the PWA ask for and
// paints each one at its exact pixel size. Run it with:
//
//   flutter test tool/generate_icons.dart
//
// It lives under `tool/` and is excluded from the suite by not being under
// `test/` — it writes files, which is not something a test should do.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:financeiro_ai/core/design_system/brand.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _fuchsia = Color(0xFFFF3D8A);
const _ink = Color(0xFF111317);

Future<void> _write(
  String path,
  int px, {
  required bool light,
  required bool bleed,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final size = px.toDouble();

  // iOS masks the corners itself and rejects transparency, so the square is
  // painted full-bleed; the maskable web icon needs the mark inside the safe
  // circle, which is why it gets more padding than the plain one.
  canvas.drawRect(
    Rect.fromLTWH(0, 0, size, size),
    Paint()..color = light ? Colors.white : _ink,
  );
  final inset = bleed ? size * .28 : size * .20;
  canvas.translate(inset, inset);
  final markSize = size - inset * 2;
  const CompassoMarkPainter(_fuchsia).paint(canvas, Size(markSize, markSize));

  final picture = recorder.endRecording();
  final image = await picture.toImage(px, px);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  await File(path).writeAsBytes(data!.buffer.asUint8List());
}

void main() {
  testWidgets('escreve os ícones', (tester) async {
    // `toImage` precisa do rasterizador de verdade: fora de `runAsync` o future
    // nunca completa e o teste fica pendurado em vez de falhar.
    await tester.runAsync(() async {
      const ios = {
        'Icon-App-20x20@1x.png': 20,
        'Icon-App-20x20@2x.png': 40,
        'Icon-App-20x20@3x.png': 60,
        'Icon-App-29x29@1x.png': 29,
        'Icon-App-29x29@2x.png': 58,
        'Icon-App-29x29@3x.png': 87,
        'Icon-App-40x40@1x.png': 40,
        'Icon-App-40x40@2x.png': 80,
        'Icon-App-40x40@3x.png': 120,
        'Icon-App-60x60@2x.png': 120,
        'Icon-App-60x60@3x.png': 180,
        'Icon-App-76x76@1x.png': 76,
        'Icon-App-76x76@2x.png': 152,
        'Icon-App-83.5x83.5@2x.png': 167,
        'Icon-App-1024x1024@1x.png': 1024,
      };
      for (final entry in ios.entries) {
        await _write(
          'ios/Runner/Assets.xcassets/AppIcon.appiconset/${entry.key}',
          entry.value,
          light: false,
          bleed: false,
        );
      }

      await _write('web/icons/Icon-192.png', 192, light: false, bleed: false);
      await _write('web/icons/Icon-512.png', 512, light: false, bleed: false);
      await _write(
        'web/icons/Icon-maskable-192.png',
        192,
        light: false,
        bleed: true,
      );
      await _write(
        'web/icons/Icon-maskable-512.png',
        512,
        light: false,
        bleed: true,
      );
      await _write('web/favicon.png', 64, light: false, bleed: false);
    });
  });
}
