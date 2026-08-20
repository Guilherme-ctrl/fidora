import 'package:financeiro_ai/core/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/cvd.dart';

/// The chart palette, checked rather than claimed.
void main() {
  const themes = {'light': FinoraPalette.light, 'dark': FinoraPalette.dark};

  // Deuteranopia and protanopia together affect roughly 8% of men. Tritanopia
  // is about 0.01%. Optimising all three equally spends the whole budget on the
  // rarest one — an earlier draft scored 38 under deuteranopia and 0.7 under
  // tritanopia — so the common pair carries the higher bar and tritanopia a
  // floor.
  const commonFloor = 18.0;
  const rareFloor = 15.0;

  themes.forEach((name, palette) {
    group('$name chart hues', () {
      test('six hues, in a fixed order', () {
        // The order is the contract: a category keeps its colour between the
        // dashboard, the projection and the invoice. Generating a colour by
        // hashing the name would break that on every rename.
        expect(palette.categorical, hasLength(6));
      });

      for (final vision in [
        Vision.normal,
        Vision.deuteranopia,
        Vision.protanopia,
      ]) {
        test('stay apart under ${vision.name}', () {
          final worst = closestPair(palette.categorical, vision);
          expect(
            worst.distance,
            greaterThanOrEqualTo(commonFloor),
            reason:
                '${worst.a.toARGB32().toRadixString(16)} and '
                '${worst.b.toARGB32().toRadixString(16)} are '
                '${worst.distance.toStringAsFixed(1)} apart',
          );
        });
      }

      test('stay apart under tritanopia', () {
        final worst = closestPair(palette.categorical, Vision.tritanopia);
        expect(worst.distance, greaterThanOrEqualTo(rareFloor));
      });
    });
  });

  test('a category keeps its hue between the themes', () {
    // Matched by hue and separated by lightness, so switching theme does not
    // renumber the legend.
    for (var i = 0; i < 6; i++) {
      final light = HSLColor.fromColor(FinoraPalette.light.categorical[i]);
      final dark = HSLColor.fromColor(FinoraPalette.dark.categorical[i]);
      final gap = (light.hue - dark.hue).abs();
      expect(
        gap < 12 || gap > 348,
        isTrue,
        reason: 'entry $i moves ${gap.toStringAsFixed(0)}° between themes',
      );
      expect(dark.lightness, greaterThan(light.lightness));
    }
  });
}
