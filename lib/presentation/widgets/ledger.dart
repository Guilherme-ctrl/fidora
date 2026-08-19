import 'package:financeiro_ai/core/theme.dart';
import 'package:financeiro_ai/core/tokens.dart';
import 'package:financeiro_ai/core/typography.dart';
import 'package:financeiro_ai/presentation/widgets/common.dart';
import 'package:flutter/material.dart';

/// The Ledger components.
///
/// These replace the three Material widgets that carried the framework's
/// appearance on their own — `Card`, and the pair of navigation widgets that
/// PR 3 takes — plus the chip, the filled button and the progress bar.
///
/// The organising idea is that a section is not an object. Content sits
/// directly on the page and what separates it is a rule; surface and radius are
/// spent only on things that really are objects: the card face, a review item,
/// a selectable option.

/// What an amount means, which decides its colour and its sign.
///
/// Named `MoneyTone` rather than `Money` because `narrative.dart` already owns
/// `Money` as the formatter typedef, and a page that shows both would not be
/// able to import them together.
enum MoneyTone {
  /// Decides from the sign of the number: positive reads as income.
  auto,

  /// Money in. Always rendered with `+`.
  income,

  /// An ordinary spend — ink, not red. Almost every row in the product is one
  /// of these, which is exactly why they cannot all shout.
  expense,

  /// A problem: negative balance, overrun budget, failed import.
  negative,

  /// Not yet confirmed.
  pending,

  /// Outside personal totals.
  ignored,

  /// Drawn on the card face.
  onCard,
}

/// The one way to put money on screen.
///
/// Before this there were 88 loose `currency.format` calls inside `Text`
/// widgets, each picking its own weight and colour, and none of them using
/// tabular figures — so `1.111,00` and `8.888,00` were different widths in the
/// same column and the eye lost the row.
class AmountText extends StatelessWidget {
  const AmountText(
    this.value, {
    super.key,
    this.tone = MoneyTone.auto,
    this.size = AmountSize.row,
    this.sign = true,
    this.align = TextAlign.end,
    this.semanticsLabel,
  });

  final double value;
  final MoneyTone tone;
  final AmountSize size;

  /// A ledger shows direction on every line. Turn it off for a total that is
  /// already labelled, like an invoice amount.
  final bool sign;

  final TextAlign align;
  final String? semanticsLabel;

  MoneyTone get _resolved => tone == MoneyTone.auto
      ? (value >= 0 ? MoneyTone.income : MoneyTone.expense)
      : tone;

  Color _colour(FinoraPalette palette) => switch (_resolved) {
    MoneyTone.income => palette.income,
    MoneyTone.expense => palette.expense,
    MoneyTone.negative => palette.negative,
    MoneyTone.pending => palette.pending,
    MoneyTone.ignored => palette.ignored,
    MoneyTone.onCard => palette.onCard,
    MoneyTone.auto => palette.ink,
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final type = context.type;
    final tone = _resolved;
    final text = currency.format(value.abs());
    // U+2212, not a hyphen: a minus sign is the same width as a digit in a
    // tabular face, so the column still lines up.
    final prefix = !sign
        ? ''
        : tone == MoneyTone.income
        ? '+'
        : '−';

    final style =
        switch (size) {
          AmountSize.hero => type.displayHero,
          AmountSize.metric => type.displayMetric,
          AmountSize.row => type.amount,
        }.copyWith(
          color: _colour(palette),
          decoration: tone == MoneyTone.ignored
              ? TextDecoration.lineThrough
              : null,
          fontWeight: tone == MoneyTone.income ? FontWeight.w600 : null,
        );

    return Text(
      '$prefix$text',
      textAlign: align,
      style: style,
      semanticsLabel:
          semanticsLabel ??
          switch (tone) {
            MoneyTone.income => 'entrada de $text',
            MoneyTone.negative => 'saldo negativo de $text',
            MoneyTone.ignored => '$text, fora dos totais pessoais',
            MoneyTone.pending => 'saída de $text, aguardando revisão',
            _ => 'saída de $text',
          },
    );
  }
}

enum AmountSize {
  /// The one figure a screen is about. Serif.
  hero,

  /// The value of a tile. Serif.
  metric,

  /// Inside a list or a table. Sans, tabular — a column has to align, and that
  /// is not the serif's job.
  row,
}

/// A section label: mono, small caps, spaced.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: context.type.labelCaps.copyWith(
      color: color ?? context.palette.inkSubtle,
    ),
  );
}

/// A block of content, separated from the next by a rule rather than lifted
/// onto a card.
class RuledSection extends StatelessWidget {
  const RuledSection({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.onTap,
    this.tooltip,
    this.first = false,
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final VoidCallback? onTap;
  final String? tooltip;

  /// The first section on a page has nothing above it to be separated from.
  final bool first;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final body = Container(
      decoration: first
          ? null
          : BoxDecoration(
              border: Border(
                top: BorderSide(color: palette.rule, width: Strokes.hairline),
              ),
            ),
      padding: const EdgeInsets.only(top: Space.lg, bottom: Space.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: Text(title, style: context.type.titleMd)),
              ?trailing,
            ],
          ),
          const SizedBox(height: Space.md),
          child,
        ],
      ),
    );

    final tappable = onTap == null
        ? body
        : InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(Radii.sm),
            child: body,
          );

    return tooltip == null
        ? tappable
        : Semantics(button: onTap != null, label: tooltip, child: tappable);
  }
}

/// A metric, headed by a heavy rule the way a ledger column is.
///
/// Its height is intrinsic. The card this replaces was placed in grids with a
/// fixed `childAspectRatio`, which overflowed the moment Dynamic Type grew the
/// text or a trend line appeared — the defect `page_overflow_test.dart` names.
class LedgerTile extends StatelessWidget {
  const LedgerTile({
    super.key,
    required this.label,
    required this.value,
    this.amount,
    this.tone = MoneyTone.expense,
    this.detail,
    this.trendLabel,
    this.trendGood,
    this.onTap,
    this.tooltip,
  });

  final String label;

  /// Pre-formatted value, for a tile that is not money. Ignored when [amount]
  /// is given.
  final String value;

  /// Money, rendered through [AmountText] so the figure is tabular.
  final double? amount;
  final MoneyTone tone;

  final String? detail;
  final String? trendLabel;

  /// Whether the movement is good news. Null keeps it neutral, which is the
  /// honest rendering when there is no baseline.
  final bool? trendGood;

  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final type = context.type;
    final trend = trendLabel;

    final body = Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: palette.ruleHeavy, width: Strokes.heavy),
        ),
      ),
      padding: const EdgeInsets.only(
        top: Space.sm,
        right: Space.lg,
        bottom: Space.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SectionLabel(label),
          const SizedBox(height: Space.xs),
          if (amount != null)
            AmountText(
              amount!,
              tone: tone,
              size: AmountSize.metric,
              sign: false,
              align: TextAlign.start,
            )
          else
            Text(value, style: type.displayMetric),
          if (detail != null) ...[
            const SizedBox(height: Space.xxs),
            Text(detail!, style: type.meta.copyWith(color: palette.inkSubtle)),
          ],
          if (trend != null) ...[
            const SizedBox(height: Space.xxs),
            Text(
              trend,
              style: type.meta.copyWith(
                color: switch (trendGood) {
                  null => palette.inkSubtle,
                  true => palette.income,
                  false => palette.negative,
                },
              ),
            ),
          ],
        ],
      ),
    );

    final tappable = onTap == null ? body : InkWell(onTap: onTap, child: body);

    return tooltip == null
        ? tappable
        : Semantics(button: onTap != null, label: tooltip, child: tappable);
  }
}

/// Lays tiles out in rows whose height comes from their tallest member.
///
/// `GridView.count` with a `childAspectRatio` cannot do that, and it is why
/// three pages overflowed at 1.3x text.
class LedgerTileRow extends StatelessWidget {
  const LedgerTileRow({super.key, required this.columns, required this.tiles});

  final int columns;
  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final rows = <Widget>[];
    for (var start = 0; start < tiles.length; start += columns) {
      final slice = tiles.sublist(
        start,
        (start + columns).clamp(0, tiles.length),
      );
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < columns; i++)
                Expanded(
                  child: i >= slice.length
                      ? const SizedBox.shrink()
                      : Container(
                          decoration: i == 0
                              ? null
                              : BoxDecoration(
                                  border: Border(
                                    left: BorderSide(
                                      color: palette.rule,
                                      width: Strokes.hairline,
                                    ),
                                  ),
                                ),
                          padding: EdgeInsets.only(left: i == 0 ? 0 : Space.lg),
                          child: slice[i],
                        ),
                ),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: Space.lg),
          rows[i],
        ],
      ],
    );
  }
}

/// The typographic mark that stands in for a merchant, with the category's
/// colour as a bar down its left edge.
///
/// It replaces an icon — and, in the prototype, an emoji. A two-letter mark
/// tells `Mercado Extra` from `Magazine Luiza` in a way a generic shopping
/// glyph never did.
class CategoryMark extends StatelessWidget {
  const CategoryMark({
    super.key,
    required this.text,
    this.color,
    this.size = 26,
  });

  final String text;
  final Color? color;
  final double size;

  /// Two letters from a merchant name: initials when there are two words,
  /// otherwise the first two letters.
  static String initials(String name) {
    final words = name
        .split(RegExp(r'[\s·—-]+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      final word = words.first;
      return (word.length == 1 ? word : word.substring(0, 2)).toUpperCase();
    }
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.xs),
        border: Border(
          top: BorderSide(color: palette.rule),
          right: BorderSide(color: palette.rule),
          bottom: BorderSide(color: palette.rule),
          left: BorderSide(
            color: color ?? palette.categorical.first,
            width: Strokes.mark,
          ),
        ),
      ),
      child: Text(
        text,
        style: context.type.meta.copyWith(
          fontSize: size * .38,
          fontWeight: FontWeight.w600,
          color: palette.inkMuted,
        ),
      ),
    );
  }
}

/// A ledger line: mark, what it was, and the amount in its own column behind a
/// vertical rule.
///
/// The rule is the point. On a wide screen the eye loses the row between the
/// merchant and the number, and a ruled column is what a real ledger uses to
/// stop that happening.
class LedgerRow extends StatelessWidget {
  const LedgerRow({
    super.key,
    required this.title,
    required this.meta,
    required this.amount,
    this.tone = MoneyTone.expense,
    this.mark,
    this.markColor,
    this.tag,
    this.onTap,
    this.zebra = false,
    this.first = false,
  });

  final String title;
  final String meta;
  final double amount;
  final MoneyTone tone;
  final String? mark;
  final Color? markColor;
  final Widget? tag;
  final VoidCallback? onTap;
  final bool zebra;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final type = context.type;

    final row = Container(
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      // Colour lives in the decoration, never beside it: `Container` asserts
      // that only one of the two is given.
      decoration: BoxDecoration(
        color: zebra ? palette.sunken : null,
        border: first
            ? null
            : Border(
                top: BorderSide(color: palette.rule, width: Strokes.hairline),
              ),
      ),
      child: Row(
        children: [
          CategoryMark(
            text: mark ?? CategoryMark.initials(title),
            color: markColor,
          ),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: type.bodyMd,
                ),
                Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: type.meta.copyWith(color: palette.inkSubtle),
                ),
              ],
            ),
          ),
          if (tag != null) ...[const SizedBox(width: Space.xs), tag!],
          const SizedBox(width: Space.sm),
          Container(
            constraints: const BoxConstraints(minWidth: 104),
            padding: const EdgeInsets.only(left: Space.md),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: palette.rule, width: Strokes.hairline),
              ),
            ),
            child: AmountText(amount, tone: tone),
          ),
        ],
      ),
    );

    return onTap == null ? row : InkWell(onTap: onTap, child: row);
  }
}

/// A state, in the voice of a ledger annotation: mono, small caps, outlined.
/// Replaces `Chip`, whose filled pill is unmistakably Material.
class MonoTag extends StatelessWidget {
  const MonoTag(this.text, {super.key, this.color, this.icon});
  final String text;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tint = color ?? palette.inkSubtle;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.xxs + 1,
        vertical: 1,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.xs),
        border: Border.all(color: tint, width: Strokes.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: tint),
            const SizedBox(width: 3),
          ],
          // A tag sits inside a Wrap and its text is spaced small caps, which
          // grows fast: at 2x Dynamic Type a two-word tag overran its own row.
          // It wraps to a second line rather than clipping, because the words
          // are the meaning.
          Flexible(
            child: Text(
              text.toUpperCase(),
              style: context.type.labelCaps.copyWith(
                color: tint,
                fontSize: 9.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The primary action: ink, not a hue.
///
/// A tonal button in the seed colour is the loudest tell of a generated theme,
/// and it also miscommunicates — it says "brand" where the interface means
/// "this is the thing to press".
class InkButton extends StatelessWidget {
  const InkButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.secondary = false,
    this.dense = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Outlined rather than filled.
  final bool secondary;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = ButtonStyle(
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.sm)),
      ),
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(
          horizontal: dense ? Space.sm : Space.md,
          vertical: dense ? Space.xxs + 1 : Space.xs,
        ),
      ),
      textStyle: WidgetStatePropertyAll(
        context.type.bodySm.copyWith(fontWeight: FontWeight.w600),
      ),
      backgroundColor: WidgetStatePropertyAll(
        secondary ? Colors.transparent : palette.action,
      ),
      foregroundColor: WidgetStatePropertyAll(
        secondary ? palette.ink : palette.onAction,
      ),
      side: secondary
          ? WidgetStatePropertyAll(BorderSide(color: palette.ruleStrong))
          : null,
      elevation: const WidgetStatePropertyAll(0),
    );

    final child = icon == null
        ? Text(label)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16),
              const SizedBox(width: Space.xs),
              Flexible(child: Text(label)),
            ],
          );

    return TextButton(onPressed: onPressed, style: style, child: child);
  }
}

/// A progress track drawn as a rule: square, thin, no radius.
class RuleBar extends StatelessWidget {
  const RuleBar({
    super.key,
    required this.value,
    this.over = false,
    this.height = 4,
  });

  final double value;
  final bool over;
  final double height;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: [
            Container(color: palette.rule),
            Container(
              width: constraints.maxWidth * value.clamp(0.0, 1.0),
              color: over ? palette.negative : palette.ink,
            ),
          ],
        ),
      ),
    );
  }
}

/// The colour a category keeps everywhere.
///
/// Resolved from the fixed order of [FinoraPalette.categorical] by hashing the
/// name into a slot — stable for a given name, and the same in the dashboard,
/// the projection and the invoice. It is a fallback: a category that carries
/// its own stored colour uses that instead.
Color categoryColourFor(BuildContext context, String category) {
  final palette = context.palette.categorical;
  if (category.isEmpty) return palette.first;
  var hash = 0;
  for (final unit in category.toLowerCase().codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return palette[hash % palette.length];
}
