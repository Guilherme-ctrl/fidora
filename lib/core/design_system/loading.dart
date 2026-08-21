import 'package:financeiro_ai/core/theme/theme.dart';
import 'package:financeiro_ai/core/theme/tokens.dart';
import 'package:flutter/material.dart';

/// Waiting, drawn.
///
/// The product had eighteen bare `CircularProgressIndicator`s and one static
/// skeleton. A centred Material spinner is the absence of a decision: it says
/// "something is happening" and nothing about what, it discards the shape of
/// the screen the person just asked for, and it looks the same in an app that
/// was designed and an app that was not.
///
/// These primitives draw the shape of what is coming. A list loads as rows, a
/// form as fields, the ledger as its own layout — so the page does not jump
/// when the data lands, and the person can already see what they are waiting
/// for.
///
/// **Reduced motion is honoured, and that is also what makes goldens stable.**
/// When the platform asks for less animation, the pulse renders at its resting
/// value instead of animating. A reference image captures that frame, so these
/// widgets can be photographed without the test fighting a running tween.
class Skeleton extends StatefulWidget {
  const Skeleton({
    required this.child,
    super.key,
  });

  /// Any subtree of [SkeletonBox]es. The pulse is driven once here and shared,
  /// so twenty rows breathe together rather than each on its own phase.
  final Widget child;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Motion.pulse,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still) {
      return _SkeletonPulse(value: _restingPulse, child: widget.child);
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => _SkeletonPulse(
        value: Curves.easeInOut.transform(_controller.value),
        child: widget.child,
      ),
    );
  }
}

/// Where the pulse rests when motion is reduced.
///
/// Mid-sweep rather than either end: at 0 the blocks are so faint they read as
/// empty space, and at 1 they read as filled content.
const _restingPulse = 0.5;

class _SkeletonPulse extends InheritedWidget {
  const _SkeletonPulse({required this.value, required super.child});

  final double value;

  static double of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_SkeletonPulse>()
          ?.value ??
      _restingPulse;

  @override
  bool updateShouldNotify(_SkeletonPulse old) => old.value != value;
}

/// One placeholder shape.
///
/// Sized like the thing it stands in for, which is the whole point: a
/// skeleton that does not match its content is a second layout that also has
/// to be maintained, and the page still jumps when the data arrives.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    this.height = 16,
    this.width = double.infinity,
    this.radius = Radii.xs,
    super.key,
  });

  const SkeletonBox.text({this.width = double.infinity, super.key})
    : height = 13,
      radius = Radii.xs;

  final double height;
  final double width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // Between the rule and the sunken surface: visible on canvas and on a
    // card, without ever being mistaken for real content.
    final color = Color.lerp(
      palette.rule,
      palette.sunken,
      _SkeletonPulse.of(context),
    );
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// A ledger row, before it has a transaction in it.
///
/// Matches `LedgerRow`: a mark, a title over a meta line, an amount on the
/// right. The widths are deliberately uneven — every line the same length
/// reads as a table of blanks rather than as text arriving.
class SkeletonRow extends StatelessWidget {
  const SkeletonRow({this.first = false, this.seed = 0, super.key});

  final bool first;

  /// Varies the widths down a list, so the placeholder looks like prose
  /// waiting rather than a grid.
  final int seed;

  static const _titles = [148.0, 196.0, 120.0, 172.0, 134.0];
  static const _metas = [92.0, 116.0, 78.0, 104.0, 88.0];

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: Space.md),
    decoration: first
        ? null
        : BoxDecoration(
            border: Border(top: BorderSide(color: context.palette.rule)),
          ),
    child: Row(
      children: [
        const SkeletonBox(height: 30, width: 30, radius: Radii.full),
        const SizedBox(width: Space.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox.text(width: _titles[seed % _titles.length]),
              const SizedBox(height: Space.sm),
              SkeletonBox.text(width: _metas[seed % _metas.length]),
            ],
          ),
        ),
        const SizedBox(width: Space.md),
        const SkeletonBox(height: 15, width: 78),
      ],
    ),
  );
}

/// A list that has not arrived.
class SkeletonList extends StatelessWidget {
  /// Fills a screen, and scrolls like the list it replaces.
  const SkeletonList({this.rows = 6, this.padding, super.key})
    : _inline = false;

  /// Sits inside something that already scrolls.
  ///
  /// A `ListView` nested in another `ListView` has unbounded height and throws,
  /// which is exactly what happened the first time this replaced the spinner
  /// inside the import-batches card. This variant is a `Column` and has no
  /// viewport of its own.
  const SkeletonList.inline({this.rows = 3, this.padding, super.key})
    : _inline = true;

  final int rows;
  final EdgeInsets? padding;
  final bool _inline;

  @override
  Widget build(BuildContext context) {
    final children = [
      for (var i = 0; i < rows; i++) SkeletonRow(first: i == 0, seed: i),
    ];
    return Skeleton(
      child: Semantics(
        label: 'Carregando',
        // Excluded from the tree below so a screen reader announces
        // "carregando" once, instead of reading out a dozen anonymous boxes.
        excludeSemantics: true,
        child: _inline
            ? Padding(
                padding: padding ?? EdgeInsets.zero,
                child: Column(mainAxisSize: MainAxisSize.min, children: children),
              )
            : ListView(
                padding: padding ?? const EdgeInsets.fromLTRB(18, 20, 18, 32),
                children: children,
              ),
      ),
    );
  }
}

/// The spinner that goes inside a button while it is submitting.
///
/// Six forms wrote this by hand as `CircularProgressIndicator(strokeWidth: 2)`
/// inside a `SizedBox.square(dimension: 20)`, each with its own dimension and
/// stroke. A button is the one place a spinner is right: there is no shape to
/// preserve, and the label must not move.
class BusySpinner extends StatelessWidget {
  const BusySpinner({this.size = 20, this.onAction = true, super.key});

  final double size;

  /// Whether it sits on a filled action, where it must use the ink that reads
  /// against the action colour rather than the page's.
  final bool onAction;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CircularProgressIndicator(
      strokeWidth: size <= 16 ? 2 : 2.4,
      color: onAction ? context.palette.onAction : context.palette.accent,
    ),
  );
}
