import 'package:financeiro_ai/core/tokens.dart';
import 'package:financeiro_ai/core/typography.dart';
import 'package:flutter/material.dart';

/// The Ledger palette.
///
/// Every value below was measured before it was written: `test/theme_test.dart`
/// runs the WCAG ratio for each token against canvas, surface and sunken, and
/// `test/categorical_test.dart` simulates deuteranopia, protanopia and
/// tritanopia over the chart hues. Two of the first drafts failed there and
/// never reached this file.
///
/// What changed from the previous palette, and why:
///
/// **The ground stopped being beige.** `#F5F3EC` was not a brand colour; it was
/// Material 3's surface tint at a warm temperature, and it is what forced every
/// piece of content to become a white card floating on a wash. The ground is
/// now near-neutral paper, the same value as the raised surface in all but a
/// hair, and what separates content is a rule.
///
/// **The primary action stopped being a colour.** A tonal button in the seed
/// colour is the single loudest tell of a generated theme. [action] is ink.
///
/// **A spend stopped being red.** In a personal-finance ledger almost every row
/// is a spend, so painting them all red destroys the hierarchy and leaves
/// nothing for a real problem. [expense] is ink; [negative] means a negative
/// balance, an overrun budget or a failed import.
///
/// **[pending] is the same ink-blue as [accent].** An entry waiting for review
/// is a task, not a fault. Amber said "something is wrong" about the most
/// ordinary state in the product.
@immutable
class FinoraPalette extends ThemeExtension<FinoraPalette> {
  const FinoraPalette({
    required this.ink,
    required this.inkMuted,
    required this.inkSubtle,
    required this.canvas,
    required this.surface,
    required this.sunken,
    required this.rule,
    required this.ruleStrong,
    required this.ruleHeavy,
    required this.action,
    required this.onAction,
    required this.accent,
    required this.accentSoft,
    required this.income,
    required this.negative,
    required this.pending,
    required this.ignored,
    required this.categorical,
    required this.cardGradient,
    required this.onCard,
  });

  /// Primary text, and the colour of an ordinary spend.
  final Color ink;

  /// Secondary text. At least 4.5:1 on all three grounds.
  final Color inkMuted;

  /// The smallest captions. Also at least 4.5:1 — including against [sunken],
  /// the zebra ground, which is what the previous value failed on.
  final Color inkSubtle;

  /// The page. Content sits directly on it; there is no tint to lift off.
  final Color canvas;

  /// Reserved for a discrete object — the card face, a review item, a
  /// selectable option. A section is not an object and does not get one.
  final Color surface;

  /// Alternating row and table ground.
  final Color sunken;

  /// The ordinary rule: what separates one row or section from the next.
  /// Decorative, so it carries no contrast requirement.
  final Color rule;

  /// A component boundary — a field, a button outline. WCAG 1.4.11 asks 3:1
  /// for anything that identifies a control, which the old hairline missed by
  /// a wide margin.
  final Color ruleStrong;

  /// The 2px rule that heads a column or a tile.
  final Color ruleHeavy;

  /// The primary action. Ink, not a hue.
  final Color action;

  /// Text and icons on [action].
  final Color onAction;

  /// Pen ink. Active rule, focus ring, an entry awaiting review — anywhere
  /// there is something to do. It never fills a surface.
  final Color accent;

  /// The faintest wash of [accent]: the row under the cursor, the suggestion
  /// band on a review item.
  final Color accentSoft;

  /// Money in. Always rendered with a `+`, so the colour is reinforcement and
  /// never the only carrier.
  final Color income;

  /// A problem: negative balance, overrun budget, failed import. Not a spend.
  final Color negative;

  /// Awaiting review. The same ink-blue as [accent] on purpose.
  final Color pending;

  /// Outside personal totals. Deliberately equal to [inkSubtle]: anything
  /// lighter fails AA, and an ignored row is still something a person has to
  /// read. The strike-through and the tag carry the meaning.
  final Color ignored;

  /// Chart hues, in fixed order. A category keeps its colour between the
  /// dashboard, the projection and the invoice, so the entries are matched by
  /// hue across the two themes and differ from each other by lightness as well
  /// — that is what survives colour-vision deficiency.
  final List<Color> categorical;

  /// The credit-card face.
  final List<Color> cardGradient;
  final Color onCard;

  /// An ordinary spend. Ink, not red.
  Color get expense => ink;

  static const light = FinoraPalette(
    ink: Color(0xFF0E1112),
    inkMuted: Color(0xFF525A5B),
    inkSubtle: Color(0xFF656D6E),
    canvas: Color(0xFFFBFBF9),
    surface: Color(0xFFFFFFFF),
    sunken: Color(0xFFF3F4F1),
    rule: Color(0xFFE3E5E1),
    ruleStrong: Color(0xFF767E7D),
    ruleHeavy: Color(0xFF0E1112),
    action: Color(0xFF0E1112),
    onAction: Color(0xFFFBFBF9),
    accent: Color(0xFF1D4E89),
    accentSoft: Color(0xFFE8EEF7),
    income: Color(0xFF0B6B4F),
    negative: Color(0xFFA33A1F),
    pending: Color(0xFF1D4E89),
    ignored: Color(0xFF656D6E),
    categorical: [
      Color(0xFF06485B),
      Color(0xFF8D2F36),
      Color(0xFF695299),
      Color(0xFF177B63),
      Color(0xFF677B98),
      Color(0xFF788E57),
    ],
    cardGradient: [Color(0xFF14181A), Color(0xFF2F3A38)],
    onCard: Color(0xFFFFFFFF),
  );

  static const dark = FinoraPalette(
    ink: Color(0xFFEDEFEC),
    inkMuted: Color(0xFF9AA3A2),
    inkSubtle: Color(0xFF8A9392),
    canvas: Color(0xFF0E1112),
    surface: Color(0xFF161A1B),
    sunken: Color(0xFF0A0D0D),
    rule: Color(0xFF232827),
    ruleStrong: Color(0xFF666E6D),
    ruleHeavy: Color(0xFFEDEFEC),
    action: Color(0xFFEDEFEC),
    onAction: Color(0xFF0E1112),
    accent: Color(0xFF7FB0E8),
    accentSoft: Color(0xFF121A24),
    income: Color(0xFF5CC79B),
    negative: Color(0xFFE5836A),
    pending: Color(0xFF7FB0E8),
    ignored: Color(0xFF8A9392),
    categorical: [
      Color(0xFF4F8397),
      Color(0xFFD67071),
      Color(0xFFAE93E0),
      Color(0xFF69C4A8),
      Color(0xFFB4C8E8),
      Color(0xFFCCE2A6),
    ],
    cardGradient: [Color(0xFF0C0F10), Color(0xFF333D3A)],
    onCard: Color(0xFFFFFFFF),
  );

  // ---------------------------------------------------------------------------
  // Migration bridges.
  //
  // 270 call sites read this palette. Renaming the fields in one commit would
  // mean resolving every one of them before anything compiles, and ~145 of them
  // are judgement calls rather than renames: `brand` was used for both action
  // and emphasis, `danger` for both an ordinary spend and a real problem.
  //
  // These getters keep the app building, and the deprecation warnings are the
  // worklist. PR 2 removes most of them by absorbing the call sites into
  // components; PR 5 deletes what is left, and a clean `dart analyze` is the
  // gate.
  // ---------------------------------------------------------------------------

  @Deprecated('Split into `action` (a button) and `accent` (emphasis). PR 5.')
  Color get brand => accent;

  @Deprecated('Use `accentSoft`. PR 5.')
  Color get brandSoft => accentSoft;

  @Deprecated('Use `accent`. PR 5.')
  Color get onBrandSoft => accent;

  @Deprecated(
    'Split into `expense` (ordinary) and `negative` (a problem). PR 5.',
  )
  Color get danger => negative;

  @Deprecated('Use `pending`. PR 5.')
  Color get warning => pending;

  @Deprecated('Use `pending`. PR 5.')
  Color get onWarning => pending;

  @Deprecated('Use `rule`, or `ruleStrong` for a component boundary. PR 5.')
  Color get hairline => rule;

  @Deprecated('Use `accent`. PR 5.')
  Color get info => accent;

  @override
  FinoraPalette copyWith({
    Color? ink,
    Color? inkMuted,
    Color? inkSubtle,
    Color? canvas,
    Color? surface,
    Color? sunken,
    Color? rule,
    Color? ruleStrong,
    Color? ruleHeavy,
    Color? action,
    Color? onAction,
    Color? accent,
    Color? accentSoft,
    Color? income,
    Color? negative,
    Color? pending,
    Color? ignored,
    List<Color>? categorical,
    List<Color>? cardGradient,
    Color? onCard,
  }) => FinoraPalette(
    ink: ink ?? this.ink,
    inkMuted: inkMuted ?? this.inkMuted,
    inkSubtle: inkSubtle ?? this.inkSubtle,
    canvas: canvas ?? this.canvas,
    surface: surface ?? this.surface,
    sunken: sunken ?? this.sunken,
    rule: rule ?? this.rule,
    ruleStrong: ruleStrong ?? this.ruleStrong,
    ruleHeavy: ruleHeavy ?? this.ruleHeavy,
    action: action ?? this.action,
    onAction: onAction ?? this.onAction,
    accent: accent ?? this.accent,
    accentSoft: accentSoft ?? this.accentSoft,
    income: income ?? this.income,
    negative: negative ?? this.negative,
    pending: pending ?? this.pending,
    ignored: ignored ?? this.ignored,
    categorical: categorical ?? this.categorical,
    cardGradient: cardGradient ?? this.cardGradient,
    onCard: onCard ?? this.onCard,
  );

  @override
  FinoraPalette lerp(covariant FinoraPalette? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    List<Color> mixAll(List<Color> a, List<Color> b) => [
      for (var i = 0; i < a.length; i++) mix(a[i], b[i]),
    ];
    return FinoraPalette(
      ink: mix(ink, other.ink),
      inkMuted: mix(inkMuted, other.inkMuted),
      inkSubtle: mix(inkSubtle, other.inkSubtle),
      canvas: mix(canvas, other.canvas),
      surface: mix(surface, other.surface),
      sunken: mix(sunken, other.sunken),
      rule: mix(rule, other.rule),
      ruleStrong: mix(ruleStrong, other.ruleStrong),
      ruleHeavy: mix(ruleHeavy, other.ruleHeavy),
      action: mix(action, other.action),
      onAction: mix(onAction, other.onAction),
      accent: mix(accent, other.accent),
      accentSoft: mix(accentSoft, other.accentSoft),
      income: mix(income, other.income),
      negative: mix(negative, other.negative),
      pending: mix(pending, other.pending),
      ignored: mix(ignored, other.ignored),
      categorical: mixAll(categorical, other.categorical),
      cardGradient: mixAll(cardGradient, other.cardGradient),
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
  final scheme =
      ColorScheme.fromSeed(
        seedColor: palette.accent,
        brightness: brightness,
      ).copyWith(
        primary: palette.action,
        onPrimary: palette.onAction,
        secondary: palette.accent,
        tertiary: palette.income,
        surface: palette.canvas,
        onSurface: palette.ink,
        surfaceContainerLowest: palette.surface,
        error: palette.negative,
        outline: palette.ruleStrong,
        outlineVariant: palette.rule,
      );

  OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
    borderRadius: const BorderRadius.all(Radius.circular(Radii.sm)),
    borderSide: BorderSide(color: color, width: width),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: palette.canvas,
    extensions: [palette, LedgerText.standard],
    // The card keeps an outline for as long as `Card` is still in the tree.
    // On the old beige ground a white card lifted off by itself; on paper it
    // has nothing to lift off, and with elevation zero its edges would simply
    // disappear. PR 2 replaces the widget with a ruled section and this goes
    // with it.
    cardTheme: CardThemeData(
      elevation: 0,
      color: palette.surface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(Radii.md)),
        side: BorderSide(color: palette.rule, width: Strokes.hairline),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: palette.rule,
      space: 1,
      thickness: Strokes.hairline,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: palette.canvas,
      foregroundColor: palette.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    // A field sits on the page ground on some screens and on an object in
    // others, so no fill can contrast with both: the outline is what makes it
    // read as a field, and `ruleStrong` is the value that clears 3:1.
    inputDecorationTheme: InputDecorationTheme(
      filled: false,
      border: border(palette.ruleStrong, Strokes.hairline),
      enabledBorder: border(palette.ruleStrong, Strokes.hairline),
      focusedBorder: border(palette.accent, Strokes.heavy),
      errorBorder: border(palette.negative, Strokes.hairline),
      focusedErrorBorder: border(palette.negative, Strokes.heavy),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: palette.canvas,
      indicatorColor: palette.accentSoft,
      surfaceTintColor: Colors.transparent,
      height: 68,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: palette.canvas,
      indicatorColor: palette.accentSoft,
      selectedIconTheme: IconThemeData(color: palette.accent),
    ),
  );
}
