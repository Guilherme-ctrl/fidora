import 'package:financeiro_ai/core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/contrast.dart';

void main() {
  group('Contrast — the audit measured 3.2:1 and 4.0:1 here', () {
    for (final entry in {
      'light': FinoraPalette.light,
      'dark': FinoraPalette.dark,
    }.entries) {
      final name = entry.key;
      final palette = entry.value;

      test('$name: primary text clears AA on both grounds', () {
        expect(contrast(palette.ink, palette.canvas), greaterThanOrEqualTo(aa));
        expect(
          contrast(palette.ink, palette.surface),
          greaterThanOrEqualTo(aa),
        );
      });

      test('$name: secondary text clears AA on both grounds', () {
        expect(
          contrast(palette.inkMuted, palette.canvas),
          greaterThanOrEqualTo(aa),
        );
        expect(
          contrast(palette.inkMuted, palette.surface),
          greaterThanOrEqualTo(aa),
        );
      });

      test('$name: the smallest captions clear AA on both grounds', () {
        expect(
          contrast(palette.inkSubtle, palette.canvas),
          greaterThanOrEqualTo(aa),
        );
        expect(
          contrast(palette.inkSubtle, palette.surface),
          greaterThanOrEqualTo(aa),
        );
      });

      test('$name: text on the brand tint clears AA', () {
        expect(
          contrast(palette.onBrandSoft, palette.brandSoft),
          greaterThanOrEqualTo(aa),
        );
      });

      test('$name: danger text clears AA on the card surface', () {
        expect(
          contrast(palette.danger, palette.surface),
          greaterThanOrEqualTo(aa),
        );
      });

      test('$name: warning text clears AA on the card surface', () {
        expect(
          contrast(palette.onWarning, palette.surface),
          greaterThanOrEqualTo(aa),
        );
      });
    }
  });

  group('Theme wiring', () {
    test('both brightnesses carry the palette extension', () {
      final light = buildAppTheme();
      final dark = buildAppTheme(brightness: Brightness.dark);
      expect(light.extension<FinoraPalette>(), FinoraPalette.light);
      expect(dark.extension<FinoraPalette>(), FinoraPalette.dark);
      expect(dark.brightness, Brightness.dark);
    });

    test('surfaces differ between the themes', () {
      expect(FinoraPalette.light.canvas, isNot(FinoraPalette.dark.canvas));
      expect(FinoraPalette.light.surface, isNot(FinoraPalette.dark.surface));
    });

    test('the scaffold follows the palette canvas', () {
      expect(
        buildAppTheme(brightness: Brightness.dark).scaffoldBackgroundColor,
        FinoraPalette.dark.canvas,
      );
    });

    testWidgets('context.palette resolves the active theme', (tester) async {
      late FinoraPalette seen;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          darkTheme: buildAppTheme(brightness: Brightness.dark),
          themeMode: ThemeMode.dark,
          home: Builder(
            builder: (context) {
              seen = context.palette;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(seen, FinoraPalette.dark);
    });

    test('lerp stays on the palette type', () {
      final mixed = FinoraPalette.light.lerp(FinoraPalette.dark, 0.5);
      expect(mixed, isA<FinoraPalette>());
      expect(mixed.ink, isNot(FinoraPalette.light.ink));
    });
  });
}
