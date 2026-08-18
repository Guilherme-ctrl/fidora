import 'package:flutter/material.dart';

/// Brand seeds. These are the light-mode source values; every widget reads its
/// colours from [FinoraPalette] so the same code renders in either theme.
const ink = Color(0xFF17211B);
const moss = Color(0xFF1F6B4F);
const mint = Color(0xFFCDEBDD);
const canvas = Color(0xFFF5F3EC);
const coral = Color(0xFFE06B4F);
const gold = Color(0xFFE5B653);

/// Semantic colours for the app, resolved per theme.
///
/// Secondary text used to be `ink` at 50–58% opacity, which measured 3.2:1 and
/// 4.0:1 against the page — below the 4.5:1 WCAG AA needs for normal text, and
/// it was used on 11–12px captions. [inkMuted] and [inkSubtle] are solid
/// values chosen to clear that bar on both the page and the card surface.
@immutable
class FinoraPalette extends ThemeExtension<FinoraPalette> {
  const FinoraPalette({
    required this.ink,
    required this.inkMuted,
    required this.inkSubtle,
    required this.brand,
    required this.brandSoft,
    required this.onBrandSoft,
    required this.canvas,
    required this.surface,
    required this.danger,
    required this.warning,
    required this.onWarning,
    required this.info,
    required this.hairline,
    required this.cardGradient,
    required this.onCard,
  });

  /// Primary text.
  final Color ink;

  /// Secondary text: subtitles, list captions. At least 4.5:1 on canvas and
  /// surface.
  final Color inkMuted;

  /// Tertiary text: the smallest captions. Also at least 4.5:1.
  final Color inkSubtle;

  final Color brand;
  final Color brandSoft;

  /// Text and icons drawn on [brandSoft].
  final Color onBrandSoft;

  final Color canvas;
  final Color surface;
  final Color danger;
  final Color warning;

  /// Text drawn on a [warning] tint, where [warning] itself is too light.
  final Color onWarning;

  final Color info;

  /// Dividers, chart grid lines and progress tracks.
  final Color hairline;

  /// The credit-card face.
  final List<Color> cardGradient;
  final Color onCard;

  static const light = FinoraPalette(
    ink: Color(0xFF17211B),
    inkMuted: Color(0xFF4A574E),
    inkSubtle: Color(0xFF5E6B62),
    brand: Color(0xFF1F6B4F),
    brandSoft: Color(0xFFCDEBDD),
    onBrandSoft: Color(0xFF14503A),
    canvas: Color(0xFFF5F3EC),
    surface: Colors.white,
    danger: Color(0xFFB23F22),
    warning: Color(0xFFE5B653),
    onWarning: Color(0xFF7A5410),
    info: Color(0xFF4A5488),
    hairline: Color(0xFFDAD6C9),
    cardGradient: [Color(0xFF193C30), Color(0xFF285F49)],
    onCard: Colors.white,
  );

  static const dark = FinoraPalette(
    ink: Color(0xFFE7ECE4),
    inkMuted: Color(0xFFA9B5AB),
    inkSubtle: Color(0xFF98A69B),
    brand: Color(0xFF6DBE97),
    brandSoft: Color(0xFF1E3B2E),
    onBrandSoft: Color(0xFF9FDCBC),
    canvas: Color(0xFF10150F),
    surface: Color(0xFF191F1A),
    danger: Color(0xFFF0906F),
    warning: Color(0xFFE8C46F),
    onWarning: Color(0xFFE8C46F),
    info: Color(0xFF9AB0CE),
    hairline: Color(0xFF2C352D),
    cardGradient: [Color(0xFF16302A), Color(0xFF224C3D)],
    onCard: Colors.white,
  );

  @override
  FinoraPalette copyWith({
    Color? ink,
    Color? inkMuted,
    Color? inkSubtle,
    Color? brand,
    Color? brandSoft,
    Color? onBrandSoft,
    Color? canvas,
    Color? surface,
    Color? danger,
    Color? warning,
    Color? onWarning,
    Color? info,
    Color? hairline,
    List<Color>? cardGradient,
    Color? onCard,
  }) => FinoraPalette(
    ink: ink ?? this.ink,
    inkMuted: inkMuted ?? this.inkMuted,
    inkSubtle: inkSubtle ?? this.inkSubtle,
    brand: brand ?? this.brand,
    brandSoft: brandSoft ?? this.brandSoft,
    onBrandSoft: onBrandSoft ?? this.onBrandSoft,
    canvas: canvas ?? this.canvas,
    surface: surface ?? this.surface,
    danger: danger ?? this.danger,
    warning: warning ?? this.warning,
    onWarning: onWarning ?? this.onWarning,
    info: info ?? this.info,
    hairline: hairline ?? this.hairline,
    cardGradient: cardGradient ?? this.cardGradient,
    onCard: onCard ?? this.onCard,
  );

  @override
  FinoraPalette lerp(covariant FinoraPalette? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return FinoraPalette(
      ink: mix(ink, other.ink),
      inkMuted: mix(inkMuted, other.inkMuted),
      inkSubtle: mix(inkSubtle, other.inkSubtle),
      brand: mix(brand, other.brand),
      brandSoft: mix(brandSoft, other.brandSoft),
      onBrandSoft: mix(onBrandSoft, other.onBrandSoft),
      canvas: mix(canvas, other.canvas),
      surface: mix(surface, other.surface),
      danger: mix(danger, other.danger),
      warning: mix(warning, other.warning),
      onWarning: mix(onWarning, other.onWarning),
      info: mix(info, other.info),
      hairline: mix(hairline, other.hairline),
      cardGradient: [
        mix(cardGradient.first, other.cardGradient.first),
        mix(cardGradient.last, other.cardGradient.last),
      ],
      onCard: mix(onCard, other.onCard),
    );
  }
}

extension FinoraThemeAccess on BuildContext {
  FinoraPalette get palette =>
      Theme.of(this).extension<FinoraPalette>() ?? FinoraPalette.light;
}

ThemeData buildAppTheme({Brightness brightness = Brightness.light}) {
  final dark = brightness == Brightness.dark;
  final palette = dark ? FinoraPalette.dark : FinoraPalette.light;
  final scheme = ColorScheme.fromSeed(seedColor: moss, brightness: brightness)
      .copyWith(
        primary: palette.brand,
        onPrimary: dark ? const Color(0xFF06251A) : Colors.white,
        secondary: palette.danger,
        tertiary: palette.warning,
        surface: palette.canvas,
        onSurface: palette.ink,
        surfaceContainerLowest: palette.surface,
        error: palette.danger,
        outlineVariant: palette.hairline,
      );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: palette.canvas,
    extensions: [palette],
    cardTheme: CardThemeData(
      elevation: 0,
      color: palette.surface,
      margin: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(22)),
      ),
    ),
    dividerTheme: DividerThemeData(color: palette.hairline),
    appBarTheme: AppBarTheme(
      backgroundColor: palette.surface,
      foregroundColor: palette.ink,
      elevation: 0,
    ),
    // Fields sit on the page ground on some screens and on a card on others,
    // so no single fill can contrast with both: a hairline outline is what
    // makes the field readable as a field on either surface.
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.surface,
      border: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: palette.hairline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: palette.hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: palette.brand, width: 2),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: palette.surface,
      indicatorColor: palette.brandSoft,
      height: 72,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: palette.surface,
      indicatorColor: palette.brandSoft,
      selectedIconTheme: IconThemeData(color: palette.onBrandSoft),
    ),
  );
}
