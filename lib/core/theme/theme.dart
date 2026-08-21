import 'package:financeiro_ai/core/theme/tokens.dart';
import 'package:financeiro_ai/core/theme/typography.dart';
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
/// **And then the whole thing was too quiet.** The first palette read, in the
/// owner's words, like a scientific article. Reading the computed styles off
/// the sites of Organizze, S1NC, Nubank and Brim showed why, and it was not
/// taste: all four fill with a saturated brand colour, and all four pick a side
/// on the ground — warm off-white or deep dark. This one sat on neutral paper
/// with the least saturated colour of the five, and never let it fill anything.
///
/// Fuchsia is the one hue none of them occupies here: green is Organizze's and
/// the money cliché, aqua is S1NC's, purple in Brazil reads as Nubank, blue is
/// Brim's. It **fills** — [action] is the brand now, not ink — and it carries
/// dark text rather than white, because white on it measures 3.34:1 and fails.
///
/// **[pending] is the same ink-blue as [accent].** An entry waiting for review
/// is a task, not a fault. Amber said "something is wrong" about the most
/// ordinary state in the product.
@immutable
class CompassoPalette extends ThemeExtension<CompassoPalette> {
  const CompassoPalette({
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

  /// Os quatro valores do board da marca Compasso são `#FF3D8A`, `#111317`,
  /// `#6B6F76` e `#F2F3F5`. Os quatro entram **literais**; o resto da paleta é
  /// derivado deles e medido, porque um board de marca dá a identidade e não
  /// tem como dar os doze tons que um produto de verdade precisa.
  static const light = CompassoPalette(
    ink: Color(0xFF111317),
    inkMuted: Color(0xFF55595F),
    // O cinza do board é `#6B6F76`, e ele passa em AA sobre o fundo — mas
    // reprova sobre a zebra, a 4,15:1. Então ele fica onde de fato serve,
    // como borda de componente (`ruleStrong`), e o metadado escurece o mínimo
    // para passar nos três chãos.
    inkSubtle: Color(0xFF5F636A),
    canvas: Color(0xFFF2F3F5),
    surface: Color(0xFFFFFFFF),
    sunken: Color(0xFFE7E9EC),
    rule: Color(0xFFDFE2E6),
    ruleStrong: Color(0xFF6B6F76),
    ruleHeavy: Color(0xFF111317),
    // O preenchimento é o mesmo fúcsia nos dois temas — é a marca. O que muda
    // é o fúcsia usado como *texto*, que precisa escurecer para passar em AA
    // sobre branco.
    action: Color(0xFFFF3D8A),
    onAction: Color(0xFF111317),
    accent: Color(0xFFC2185B),
    accentSoft: Color(0xFFFDE7F0),
    income: Color(0xFF0B6B4F),
    negative: Color(0xFFB03A18),
    pending: Color(0xFFC2185B),
    ignored: Color(0xFF5F636A),
    categorical: [
      Color(0xFF553858),
      Color(0xFF7F3B3D),
      Color(0xFF3D5AA9),
      Color(0xFF5B7625),
      Color(0xFF3082A2),
      Color(0xFF4F7F76),
    ],
    cardGradient: [Color(0xFF111317), Color(0xFF2C3039)],
    onCard: Color(0xFFFFFFFF),
  );

  static const dark = CompassoPalette(
    ink: Color(0xFFF2F3F5),
    inkMuted: Color(0xFF9AA1AA),
    inkSubtle: Color(0xFF8B929B),
    canvas: Color(0xFF111317),
    surface: Color(0xFF191D23),
    sunken: Color(0xFF0B0D10),
    rule: Color(0xFF262A31),
    // O cinza do board vira a borda de componente do tema escuro: 3,68:1
    // sobre o fundo, acima dos 3:1 que a WCAG 1.4.11 pede.
    ruleStrong: Color(0xFF6B6F76),
    ruleHeavy: Color(0xFFF2F3F5),
    action: Color(0xFFFF3D8A),
    onAction: Color(0xFF111317),
    accent: Color(0xFFFF3D8A),
    accentSoft: Color(0xFF2B1420),
    income: Color(0xFF3FD98A),
    negative: Color(0xFFFF7A4D),
    pending: Color(0xFFFF3D8A),
    ignored: Color(0xFF8B929B),
    categorical: [
      Color(0xFFA280A4),
      Color(0xFFD38785),
      Color(0xFF93A6FE),
      Color(0xFFAAC570),
      Color(0xFF8CD6F9),
      Color(0xFFB0E8DC),
    ],
    cardGradient: [Color(0xFF15181D), Color(0xFF2C3039)],
    onCard: Color(0xFFFFFFFF),
  );

  @override
  CompassoPalette copyWith({
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
  }) => CompassoPalette(
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
  CompassoPalette lerp(covariant CompassoPalette? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    List<Color> mixAll(List<Color> a, List<Color> b) => [
      for (var i = 0; i < a.length; i++) mix(a[i], b[i]),
    ];
    return CompassoPalette(
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

extension CompassoThemeAccess on BuildContext {
  CompassoPalette get palette =>
      Theme.of(this).extension<CompassoPalette>() ?? CompassoPalette.light;
}

ThemeData buildAppTheme({Brightness brightness = Brightness.light}) {
  final dark = brightness == Brightness.dark;
  final palette = dark ? CompassoPalette.dark : CompassoPalette.light;
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
    // The default for everything that still builds its own `TextStyle` without
    // asking `LedgerText` for one. There are around 200 of those left, and
    // without this line each of them would fall back to the platform's default
    // face — the product would ship three considered families and still not be
    // set in them.
    fontFamily: 'Sora',
    fontFamilyFallback: const ['.SF UI Text', 'Segoe UI', 'Roboto'],
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
    // The buttons are themed rather than replaced one by one. There are 40
    // `FilledButton` call sites in four shapes — plain, `.icon`, `.tonal` and
    // styled — and rewriting each of them would be volume with no reader:
    // styling them here reaches every one, including the ones a future change
    // adds. `InkButton` stays for new code that wants the component directly.
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStatePropertyAll(palette.action),
        foregroundColor: WidgetStatePropertyAll(palette.onAction),
        elevation: const WidgetStatePropertyAll(0),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.sm)),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.xs + 2),
        ),
        textStyle: WidgetStatePropertyAll(
          LedgerText.standard.bodySm.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(palette.ink),
        side: WidgetStatePropertyAll(BorderSide(color: palette.ruleStrong)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.sm)),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.xs + 2),
        ),
        textStyle: WidgetStatePropertyAll(
          LedgerText.standard.bodySm.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(palette.accent),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.sm)),
        ),
        textStyle: WidgetStatePropertyAll(
          LedgerText.standard.bodySm.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    ),
    // A filled pill is unmistakably Material. A chip in this product is a
    // ledger annotation: outlined, square-ish, in the metadata voice.
    chipTheme: ChipThemeData(
      backgroundColor: Colors.transparent,
      selectedColor: palette.accentSoft,
      side: BorderSide(color: palette.ruleStrong),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.xs),
      ),
      labelStyle: LedgerText.standard.bodySm.copyWith(color: palette.inkMuted),
      padding: const EdgeInsets.symmetric(horizontal: Space.xxs),
      showCheckmark: false,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: palette.ink,
      contentTextStyle: LedgerText.standard.bodySm.copyWith(
        color: palette.canvas,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: palette.canvas,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        side: BorderSide(color: palette.rule, width: Strokes.hairline),
      ),
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
