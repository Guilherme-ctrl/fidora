import 'package:flutter/widgets.dart';

/// The one width scale.
///
/// Before this, eleven different thresholds were spread across the pages —
/// 470, 600, 650, 680, 700, 850, 900, 1100, 1180, 1200 and 1250 — none of them
/// written down, and a single `width >= 900` in the shell decided navigation,
/// creation and headers at once. Between 600 and 900 that handed an iPad and a
/// resized browser window the phone layout.
enum Breakpoint {
  /// Phone. Tab bar, bottom sheet, list.
  compact,

  /// Large phone landscape, small tablet. Icon rail, dialog.
  medium,

  /// Tablet, small laptop. Icon rail, simple table.
  expanded,

  /// Desktop. Full sidebar, side panel, multi-select.
  large;

  static Breakpoint of(BuildContext context) =>
      forWidth(MediaQuery.sizeOf(context).width);

  static Breakpoint forWidth(double width) => switch (width) {
    < 600 => Breakpoint.compact,
    < 905 => Breakpoint.medium,
    < 1240 => Breakpoint.expanded,
    _ => Breakpoint.large,
  };

  bool get isPhone => this == Breakpoint.compact;
  bool get hasRail => index >= Breakpoint.medium.index;
  bool get hasSidebar => this == Breakpoint.large;
  bool get hasTable => index >= Breakpoint.expanded.index;
  bool get hasSidePanel => this == Breakpoint.large;

  /// Horizontal page padding.
  double get gutter => switch (this) {
    Breakpoint.compact => 18,
    Breakpoint.medium => 24,
    _ => 32,
  };
}

/// A line of text stops being readable long before a 1920px monitor ends, and
/// a ledger row loses the eye between merchant and amount. Content is capped.
const maxContentWidth = 1440.0;
