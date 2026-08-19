/// Design tokens that do not vary with the theme.
///
/// Colour lives in `theme.dart` because it changes between light and dark;
/// space, radius and duration do not, so they are plain constants and can be
/// used from a `const` constructor.
library;

/// Spacing scale, base 4.
///
/// The audit counted 165 literal `EdgeInsets` in `lib/presentation`, on values
/// that never agreed with each other — 18 and 22 next to 20 and 12. Anything
/// outside this scale is a bug.
abstract final class Space {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 40.0;
  static const huge = 48.0;
  static const giant = 64.0;
}

/// Corner radius.
///
/// Nothing in the product is rounder than [md]. The 22 the card theme used is
/// the radius of a consumer app; 10 reads as a tool. A section is not an
/// object at all and carries no radius — it is separated by a rule.
abstract final class Radii {
  /// Transaction mark, tag.
  static const xs = 3.0;

  /// Button, field, chip.
  static const sm = 5.0;

  /// The only radius an object gets: card face, review item, selectable option.
  static const md = 10.0;

  /// Avatar, pill.
  static const full = 999.0;
}

/// Stroke widths. A rule is the product's unit of separation, so its weight
/// carries meaning: hairline separates rows, [heavy] heads a column.
abstract final class Strokes {
  static const hairline = 1.0;
  static const heavy = 2.0;

  /// The category bar on a transaction mark.
  static const mark = 3.0;
}

abstract final class Motion {
  static const micro = Duration(milliseconds: 120);
  static const panel = Duration(milliseconds: 200);
  static const sheet = Duration(milliseconds: 320);

  /// Only the headline figure counts up, and only on the dashboard.
  static const count = Duration(milliseconds: 400);
}
