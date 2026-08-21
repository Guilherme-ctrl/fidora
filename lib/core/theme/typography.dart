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

  /// Any amount inside a list or a table. Never the display voice — a column
  /// has to align, and that is the interface weight's job.
  final TextStyle amount;

  /// Card, instalment, origin, date.
  final TextStyle meta;

  /// Section label.
  final TextStyle labelCaps;

  /// One family, and it is the brand's family.
  ///
  /// Sora comes from the Compasso brand board: geometric, open, with a tall
  /// x-height that survives being set small on a phone. Everything is set in
  /// it — display, interface and metadata alike.
  ///
  /// **The mono is gone.** JetBrains Mono held the metadata since the system
  /// was called Ledger, and it was never wrong on its own terms — but small
  /// uppercase mono is precisely the readout texture behind *"parece um artigo
  /// científico"*. What the mono actually bought was column alignment, and Sora
  /// ships `tnum`, so the alignment survives the change and the terminal look
  /// does not.
  ///
  /// Sora has one axis, `wght` 100–800. The display voice is weight alone now:
  /// Archivo's width axis was a real loss, but Sora is already wide by drawing,
  /// which is the reason it reads as a display face at 40px.
  static const _sansFallback = <String>[
    '.SF UI Text',
    'Segoe UI',
    'Roboto',
    'sans-serif',
  ];

  static const _tabular = <FontFeature>[FontFeature.tabularFigures()];

  /// Heavy: the posture of a number that is the point of the screen.
  static const _display = <FontVariation>[FontVariation('wght', 700)];

  static const standard = LedgerText(
    displayHero: TextStyle(
      fontFamily: 'Sora',
      fontFamilyFallback: _sansFallback,
      fontVariations: _display,
      fontSize: 42,
      height: 1.02,
      letterSpacing: -1.4,
      fontFeatures: _tabular,
    ),
    displayMetric: TextStyle(
      fontFamily: 'Sora',
      fontFamilyFallback: _sansFallback,
      fontVariations: _display,
      fontSize: 26,
      height: 1.12,
      letterSpacing: -0.6,
      fontFeatures: _tabular,
    ),
    titleLg: TextStyle(
      fontFamily: 'Sora',
      fontFamilyFallback: _sansFallback,
      fontVariations: [FontVariation('wght', 620)],
      fontSize: 19,
      height: 1.28,
      letterSpacing: -0.3,
    ),
    titleMd: TextStyle(
      fontFamily: 'Sora',
      fontFamilyFallback: _sansFallback,
      fontVariations: [FontVariation('wght', 620)],
      fontSize: 13.5,
      height: 1.35,
      letterSpacing: -0.05,
      fontWeight: FontWeight.w600,
    ),
    bodyMd: TextStyle(
      fontFamily: 'Sora',
      fontFamilyFallback: _sansFallback,
      fontSize: 14,
      height: 1.45,
    ),
    bodySm: TextStyle(
      fontFamily: 'Sora',
      fontFamilyFallback: _sansFallback,
      fontSize: 13,
      height: 1.4,
    ),
    amount: TextStyle(
      fontFamily: 'Sora',
      fontFamilyFallback: _sansFallback,
      fontVariations: [FontVariation('wght', 560)],
      fontSize: 14,
      height: 1.4,
      fontWeight: FontWeight.w500,
      fontFeatures: _tabular,
    ),
    meta: TextStyle(
      fontFamily: 'Sora',
      fontFamilyFallback: _sansFallback,
      fontSize: 11.5,
      height: 1.4,
      letterSpacing: 0,
      fontFeatures: _tabular,
    ),
    labelCaps: TextStyle(
      fontFamily: 'Sora',
      fontFamilyFallback: _sansFallback,
      fontVariations: [FontVariation('wght', 600)],
      fontSize: 10.5,
      height: 1.35,
      fontWeight: FontWeight.w600,
      // Menos espaçamento que a versão mono: a Sora já é larga, e 1.5 de track
      // em caixa alta larga vira legenda de infográfico.
      letterSpacing: 0.9,
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
