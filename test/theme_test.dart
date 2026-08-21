import 'package:financeiro_ai/core/theme/theme.dart';
import 'package:financeiro_ai/core/theme/tokens.dart';
import 'package:financeiro_ai/core/theme/typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/contrast.dart';

/// Contrast is measured here before a value reaches the palette, not after.
///
/// The previous version of this file caught secondary text sitting at 3.2:1 and
/// 4.0:1. The Ledger palette added a third ground — `sunken`, the zebra row —
/// and the first draft of `inkSubtle` failed against exactly that one at 4.34.
void main() {
  const themes = {'light': CompassoPalette.light, 'dark': CompassoPalette.dark};

  group('Text clears AA on every ground', () {
    themes.forEach((name, palette) {
      final grounds = {
        'canvas': palette.canvas,
        'surface': palette.surface,
        'sunken': palette.sunken,
      };

      final text = {
        'ink': palette.ink,
        'inkMuted': palette.inkMuted,
        'inkSubtle': palette.inkSubtle,
        'ignored': palette.ignored,
        'accent': palette.accent,
        'income': palette.income,
        'negative': palette.negative,
        'pending': palette.pending,
      };

      text.forEach((token, colour) {
        grounds.forEach((groundName, ground) {
          test('$name: $token on $groundName', () {
            expect(
              contrast(colour, ground),
              greaterThanOrEqualTo(aa),
              reason: '$token measured ${contrast(colour, ground)}',
            );
          });
        });
      });
    });
  });

  group('Text on a tint and on the action', () {
    themes.forEach((name, palette) {
      test('$name: accent on its own wash', () {
        expect(
          contrast(palette.accent, palette.accentSoft),
          greaterThanOrEqualTo(aa),
        );
      });

      test('$name: the ink button is legible', () {
        expect(
          contrast(palette.onAction, palette.action),
          greaterThanOrEqualTo(aa),
        );
      });
    });
  });

  group('Component boundaries clear 3:1', () {
    // WCAG 1.4.11. The old `hairline` was decorative and was also being used as
    // a field outline, where it measured about 1.5:1 — a field a person could
    // not find the edge of.
    themes.forEach((name, palette) {
      for (final ground in [palette.canvas, palette.surface, palette.sunken]) {
        test('$name: ruleStrong on ${ground.toARGB32().toRadixString(16)}', () {
          expect(
            contrast(palette.ruleStrong, ground),
            greaterThanOrEqualTo(aaLarge),
          );
        });
      }
    });
  });

  group('Chart hues are visible against the page', () {
    themes.forEach((name, palette) {
      test('$name: every categorical hue clears 3:1', () {
        for (final colour in palette.categorical) {
          final worst = [
            palette.canvas,
            palette.surface,
            palette.sunken,
          ].map((g) => contrast(colour, g)).reduce((a, b) => a < b ? a : b);
          expect(
            worst,
            greaterThanOrEqualTo(aaLarge),
            reason: '${colour.toARGB32().toRadixString(16)} measured $worst',
          );
        }
      });
    });
  });

  group('Semantics that must not collapse', () {
    themes.forEach((name, palette) {
      test('$name: an ordinary spend is ink, not the problem colour', () {
        expect(palette.expense, palette.ink);
        expect(palette.expense, isNot(palette.negative));
      });

      test('$name: the primary action fills, and fills with the brand', () {
        // This asserted the opposite until the palette changed. Ink was the
        // right answer while the system was a ledger and the wrong one once it
        // had to feel like something you open every day: all four competitors
        // fill with a saturated brand colour and none of them uses ink.
        expect(palette.action, isNot(palette.ink));
        expect(palette.action, const Color(0xFFFF3D8A));
      });

      test('$name: the action carries dark text, because white fails on it', () {
        // White on #FF3D8A measures 3.34:1. The button keeps the bright colour
        // and darkens the label instead of darkening the brand.
        expect(
          contrast(palette.onAction, palette.action),
          greaterThanOrEqualTo(aa),
        );
        expect(
          contrast(Colors.white, palette.action),
          lessThan(aa),
          reason: 'se um dia passar, o rótulo branco volta a ser opção',
        );
      });

      test('$name: awaiting review reads as action, not as a fault', () {
        expect(palette.pending, palette.accent);
        expect(palette.pending, isNot(palette.negative));
      });

      test('$name: the ground is neutral, and it is one step from the surface', () {
        // O que esta regra defendia era o bege: um chão *quente*, oito pontos de
        // luminância abaixo do branco, que obrigava todo conteúdo a virar card
        // para se destacar dele. A marca Compasso traz um chão cinza de
        // propósito — `#F2F3F5` é um dos quatro valores do board — e cinza sobre
        // branco é uma relação de dois níveis, não um degradê de tinta.
        //
        // Então o que se mede agora é o que sempre importou: o chão é
        // **neutro** (não tem temperatura própria) e está a **um** passo da
        // superfície, não a três.
        final ground = HSLColor.fromColor(palette.canvas);
        expect(
          ground.saturation,
          lessThan(0.16),
          reason:
              'o chão não pode ter cor própria — foi assim que o bege entrou',
        );
        expect(
          (luminance(palette.canvas) - luminance(palette.surface)).abs(),
          lessThan(0.15),
        );
      });
    });
  });

  group('Theme wiring', () {
    test('both brightnesses carry both extensions', () {
      final light = buildAppTheme();
      final dark = buildAppTheme(brightness: Brightness.dark);
      expect(light.extension<CompassoPalette>(), CompassoPalette.light);
      expect(dark.extension<CompassoPalette>(), CompassoPalette.dark);
      expect(light.extension<LedgerText>(), LedgerText.standard);
      expect(dark.brightness, Brightness.dark);
    });

    test('every numeric style is tabular', () {
      const type = LedgerText.standard;
      for (final style in [
        type.displayHero,
        type.displayMetric,
        type.amount,
        type.meta,
      ]) {
        expect(
          style.fontFeatures?.any((f) => f.feature == 'tnum'),
          isTrue,
          reason: 'a column of amounts cannot align without tabular figures',
        );
      }
    });

    test('the corner scale is the app scale, and it stops at lg', () {
      // Os raios dobraram junto com a virada fúcsia: o objeto agora é um
      // cartão, não uma linha de razão. O que continua valendo é que existe
      // uma escala — nada escolhe um canto fora dela, e nada passa de lg
      // exceto a pílula, que é redonda de propósito.
      final shape = buildAppTheme().cardTheme.shape! as RoundedRectangleBorder;
      final radius = shape.borderRadius.resolve(TextDirection.ltr).topLeft.x;
      expect(radius, Radii.md);
      expect(<double>[Radii.xs, Radii.sm, Radii.md, Radii.lg], isNotEmpty);
      expect(radius, lessThanOrEqualTo(Radii.lg));
      expect(Radii.full, greaterThan(Radii.lg));
    });

    test('the field outline is the 3:1 rule, not the decorative one', () {
      final theme = buildAppTheme();
      final border =
          theme.inputDecorationTheme.enabledBorder! as OutlineInputBorder;
      expect(border.borderSide.color, CompassoPalette.light.ruleStrong);
    });

    test('the scaffold follows the palette canvas', () {
      expect(
        buildAppTheme(brightness: Brightness.dark).scaffoldBackgroundColor,
        CompassoPalette.dark.canvas,
      );
    });

    testWidgets('context.palette and context.type resolve the active theme', (
      tester,
    ) async {
      late CompassoPalette palette;
      late LedgerText type;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          darkTheme: buildAppTheme(brightness: Brightness.dark),
          themeMode: ThemeMode.dark,
          home: Builder(
            builder: (context) {
              palette = context.palette;
              type = context.type;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(palette, CompassoPalette.dark);
      expect(type, LedgerText.standard);
    });

    test('lerp stays on the palette type and mixes the chart hues', () {
      final mixed = CompassoPalette.light.lerp(CompassoPalette.dark, 0.5);
      expect(mixed, isA<CompassoPalette>());
      expect(mixed.ink, isNot(CompassoPalette.light.ink));
      expect(mixed.categorical.length, 6);
    });
  });
}
