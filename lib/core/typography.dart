import 'package:flutter/material.dart';

/// The type system, in three voices.
///
/// The headline figure is printed — a serif, large, with lining figures. The
/// column is machine-set — tabular, so digits line up and the eye does not
/// lose the row. Metadata is monospaced small caps: card, instalment, date,
/// tag. One sans for everything is exactly what reads as generated.
///
/// Every numeric style carries [FontFeature.tabularFigures]. The product had
/// none: `1.111,00` and `8.888,00` were different widths in the same column,
/// which is the most visible difference between a financial interface and any
/// other.
@immutable
class LedgerText extends ThemeExtension<LedgerText> {
  const LedgerText({
    required this.displayHero,
    required this.displayMetric,
    required this.titleLg,
    required this.titleMd,
    required this.bodyMd,
    required this.bodySm,
    required this.amount,
    required this.meta,
    required this.labelCaps,
  });

  /// The one figure a screen is about.
  final TextStyle displayHero;

  /// The value of a tile.
  final TextStyle displayMetric;

  final TextStyle titleLg;
  final TextStyle titleMd;
  final TextStyle bodyMd;
  final TextStyle bodySm;

  /// Any amount inside a list or a table. Never the serif — a column has to
  /// align, and that is the sans's job.
  final TextStyle amount;

  /// Card, instalment, origin, date.
  final TextStyle meta;

  /// Section label.
  final TextStyle labelCaps;

  /// Two families, and the display voice stopped being a serif.
  ///
  /// The serif was the most "printed page" thing in the system, and a printed
  /// page is exactly what the owner said this felt like. Archivo replaces both
  /// it and Inter: one family with a **width axis**, so the headline figure can
  /// be set wide and heavy while the interface stays at normal width. Same
  /// voice, two postures, one file.
  ///
  /// JetBrains Mono stays for metadata — it was never the problem.
  static const _sansFallback = <String>[
    '.SF UI Text',
    'Segoe UI',
    'Roboto',
    'sans-serif',
  ];

  static const _monoFallback = <String>[
    'SF Mono',
    'Menlo',
    'Consolas',
    'monospace',
  ];

  static const _tabular = <FontFeature>[FontFeature.tabularFigures()];

  /// Wide and heavy: the posture of a number that is the point of the screen.
  static const _display = <FontVariation>[
    FontVariation('wght', 640),
    FontVariation('wdth', 118),
  ];

  static const standard = LedgerText(
    displayHero: TextStyle(
      fontFamily: 'Archivo',
      fontFamilyFallback: _sansFallback,
      fontVariations: _display,
      fontSize: 42,
      height: 1.02,
      letterSpacing: -1.4,
      fontFeatures: _tabular,
    ),
    displayMetric: TextStyle(
      fontFamily: 'Archivo',
      fontFamilyFallback: _sansFallback,
      fontVariations: _display,
      fontSize: 26,
      height: 1.12,
      letterSpacing: -0.6,
      fontFeatures: _tabular,
    ),
    titleLg: TextStyle(
      fontFamily: 'Archivo',
      fontFamilyFallback: _sansFallback,
      fontVariations: [FontVariation('wght', 620)],
      fontSize: 19,
      height: 1.28,
      letterSpacing: -0.3,
    ),
    titleMd: TextStyle(
      fontFamily: 'Archivo',
      fontFamilyFallback: _sansFallback,
      fontVariations: [FontVariation('wght', 620)],
      fontSize: 13.5,
      height: 1.35,
      letterSpacing: -0.05,
      fontWeight: FontWeight.w600,
    ),
    bodyMd: TextStyle(
      fontFamily: 'Archivo',
      fontFamilyFallback: _sansFallback,
      fontSize: 14,
      height: 1.45,
    ),
    bodySm: TextStyle(
      fontFamily: 'Archivo',
      fontFamilyFallback: _sansFallback,
      fontSize: 13,
      height: 1.4,
    ),
    amount: TextStyle(
      fontFamily: 'Archivo',
      fontFamilyFallback: _sansFallback,
      fontVariations: [FontVariation('wght', 560)],
      fontSize: 14,
      height: 1.4,
      fontWeight: FontWeight.w500,
      fontFeatures: _tabular,
    ),
    meta: TextStyle(
      fontFamily: 'JetBrains Mono',
      fontFamilyFallback: _monoFallback,
      fontSize: 11,
      height: 1.35,
      letterSpacing: 0.2,
      fontFeatures: _tabular,
    ),
    labelCaps: TextStyle(
      fontFamily: 'JetBrains Mono',
      fontFamilyFallback: _monoFallback,
      fontVariations: [FontVariation('wght', 600)],
      fontSize: 10,
      height: 1.35,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.5,
    ),
  );

  @override
  LedgerText copyWith({
    TextStyle? displayHero,
    TextStyle? displayMetric,
    TextStyle? titleLg,
    TextStyle? titleMd,
    TextStyle? bodyMd,
    TextStyle? bodySm,
    TextStyle? amount,
    TextStyle? meta,
    TextStyle? labelCaps,
  }) => LedgerText(
    displayHero: displayHero ?? this.displayHero,
    displayMetric: displayMetric ?? this.displayMetric,
    titleLg: titleLg ?? this.titleLg,
    titleMd: titleMd ?? this.titleMd,
    bodyMd: bodyMd ?? this.bodyMd,
    bodySm: bodySm ?? this.bodySm,
    amount: amount ?? this.amount,
    meta: meta ?? this.meta,
    labelCaps: labelCaps ?? this.labelCaps,
  );

  @override
  LedgerText lerp(covariant LedgerText? other, double t) {
    if (other == null) return this;
    TextStyle mix(TextStyle a, TextStyle b) => TextStyle.lerp(a, b, t)!;
    return LedgerText(
      displayHero: mix(displayHero, other.displayHero),
      displayMetric: mix(displayMetric, other.displayMetric),
      titleLg: mix(titleLg, other.titleLg),
      titleMd: mix(titleMd, other.titleMd),
      bodyMd: mix(bodyMd, other.bodyMd),
      bodySm: mix(bodySm, other.bodySm),
      amount: mix(amount, other.amount),
      meta: mix(meta, other.meta),
      labelCaps: mix(labelCaps, other.labelCaps),
    );
  }
}

extension LedgerTextAccess on BuildContext {
  LedgerText get type =>
      Theme.of(this).extension<LedgerText>() ?? LedgerText.standard;
}
