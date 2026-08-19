import 'dart:math' as math;

import 'package:flutter/material.dart';

/// WCAG relative luminance and contrast ratio.
///
/// Extracted from `theme_test.dart` so the same harness can measure the tokens
/// the design system adds later — accent, income, negative, pending, ignored
/// and the six categorical hues — without the measurement being copied.
double luminance(Color color) {
  double channel(double raw) => raw <= 0.03928
      ? raw / 12.92
      : math.pow((raw + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

double contrast(Color a, Color b) {
  final first = luminance(a);
  final second = luminance(b);
  final lighter = math.max(first, second);
  final darker = math.min(first, second);
  return (lighter + 0.05) / (darker + 0.05);
}

/// WCAG AA for normal text.
const aa = 4.5;

/// WCAG AA for large text and for the boundary of a component.
const aaLarge = 3.0;
