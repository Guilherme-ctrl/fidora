import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Colour-vision deficiency simulation (Viénot, Brettel & Mollon 1999) and
/// CIELAB ΔE, so a categorical palette can be checked rather than asserted.
///
/// The first two drafts of the chart palette were written from intuition and
/// both failed here: hues chosen to look spread apart collapsed to ΔE 8–12
/// under deuteranopia, and one draft that scored well under it fell to ΔE 1.0
/// under tritanopia because the search had optimised for one deficiency only.
enum Vision { normal, deuteranopia, protanopia, tritanopia }

double _toLinear(double c) =>
    c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _toSrgb(double c) {
  final v = c.clamp(0.0, 1.0);
  return v <= 0.0031308 ? 12.92 * v : 1.055 * math.pow(v, 1 / 2.4) - 0.055;
}

List<double> _linear(Color c) => [
  _toLinear(c.r),
  _toLinear(c.g),
  _toLinear(c.b),
];

const _rgbToLms = [
  [17.8824, 43.5161, 4.11935],
  [3.45565, 27.1554, 3.86714],
  [0.0299566, 0.184309, 1.46709],
];

const _lmsToRgb = [
  [0.080944, -0.130504, 0.116721],
  [-0.0102485, 0.0540194, -0.113615],
  [-0.000365294, -0.00412163, 0.693513],
];

List<double> _apply(List<List<double>> m, List<double> v) => [
  for (var i = 0; i < 3; i++) m[i][0] * v[0] + m[i][1] * v[1] + m[i][2] * v[2],
];

/// [colour] as someone with [vision] sees it.
Color simulate(Color colour, Vision vision) {
  if (vision == Vision.normal) return colour;
  final lms = _apply(_rgbToLms, _linear(colour));
  final l = lms[0], m = lms[1], s = lms[2];
  final shifted = switch (vision) {
    Vision.protanopia => [2.02344 * m - 2.52581 * s, m, s],
    Vision.deuteranopia => [l, 0.494207 * l + 1.24827 * s, s],
    Vision.tritanopia => [l, m, -0.395913 * l + 0.801109 * m],
    Vision.normal => lms,
  };
  final rgb = _apply(_lmsToRgb, shifted);
  return Color.from(
    alpha: 1,
    red: _toSrgb(rgb[0]),
    green: _toSrgb(rgb[1]),
    blue: _toSrgb(rgb[2]),
  );
}

List<double> _lab(Color colour) {
  final [r, g, b] = _linear(colour);
  final x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047;
  final y = 0.2126 * r + 0.7152 * g + 0.0722 * b;
  final z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883;
  double f(double t) =>
      t > 0.008856 ? math.pow(t, 1 / 3).toDouble() : 7.787 * t + 16 / 116;
  final fx = f(x), fy = f(y), fz = f(z);
  return [116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)];
}

/// CIE76 colour difference. Below roughly 15 two categorical colours stop
/// being reliably tellable apart at the size of a 3px mark.
double deltaE(Color a, Color b) {
  final x = _lab(a), y = _lab(b);
  return math.sqrt(
    math.pow(x[0] - y[0], 2) +
        math.pow(x[1] - y[1], 2) +
        math.pow(x[2] - y[2], 2),
  );
}

/// The closest pair in [palette] under [vision].
({double distance, Color a, Color b}) closestPair(
  List<Color> palette,
  Vision vision,
) {
  var best = (distance: double.infinity, a: palette.first, b: palette.first);
  for (var i = 0; i < palette.length; i++) {
    for (var j = i + 1; j < palette.length; j++) {
      final d = deltaE(
        simulate(palette[i], vision),
        simulate(palette[j], vision),
      );
      if (d < best.distance) {
        best = (distance: d, a: palette[i], b: palette[j]);
      }
    }
  }
  return best;
}
