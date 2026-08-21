import 'package:financeiro_ai/core/theme/theme.dart';
import 'package:financeiro_ai/core/theme/tokens.dart';
import 'package:financeiro_ai/core/theme/typography.dart';
import 'package:financeiro_ai/core/design_system/ledger.dart';
import 'package:flutter/material.dart';

/// The four spaces.
///
/// Named `NavSpace` because `tokens.dart` already owns `Space` for the spacing
/// scale, and this file needs both.
///
/// Before this the product had five flat tabs and a "Mais" holding eleven real
/// destinations — Metas, Projeção, Contas, Assinaturas, Revisões, two
/// importers, Dados, Portadores, Lembretes and Regras. "Mais" was the
/// product's junk drawer, and two of the things inside it should have been
/// central: the review queue, which is the daily ritual, and the projection,
/// which is the only screen that looks forward.
///
/// `Futuro` is the grouping the product had earned and did not have: projection,
/// goals, subscriptions and instalments all answer the same question — how much
/// is already committed — and lived in three different places.
enum NavSpace {
  today('Hoje', 'o que precisa de você agora'),
  money('Dinheiro', 'o que aconteceu'),
  future('Futuro', 'o que já está comprometido'),
  settings('Ajustes', 'como o sistema pensa');

  const NavSpace(this.label, this.blurb);
  final String label;
  final String blurb;
}

/// A destination inside a space.
class Destination {
  const Destination({
    required this.space,
    required this.label,
    required this.icon,
    this.badge = 0,
    String? short,
  }) : _short = short;

  final NavSpace space;
  final String label;
  final IconData icon;

  final String? _short;

  /// What the phone's tab bar shows. A tab is about 70pt wide and "Precisa de
  /// você" was arriving as "Precisa de v…".
  String get short => _short ?? label;

  /// A count worth interrupting for. Only the review queue uses it.
  final int badge;

  /// Carries `short` across. Dropping it here is what made the one destination
  /// that has a badge — the review queue — the one destination whose tab label
  /// was still truncated after the short labels landed.
  Destination withBadge(int value) => Destination(
    space: space,
    label: label,
    short: _short,
    icon: icon,
    badge: value,
  );
}

const destinations = <Destination>[
  Destination(
    space: NavSpace.today,
    label: 'Precisa de você',
    short: 'Hoje',
    icon: Icons.bolt_outlined,
  ),
  Destination(
    space: NavSpace.money,
    label: 'Visão geral',
    short: 'Visão',
    icon: Icons.equalizer_rounded,
  ),
  Destination(
    space: NavSpace.money,
    label: 'Histórico',
    icon: Icons.list_alt_rounded,
  ),
  Destination(
    space: NavSpace.money,
    label: 'Categorias',
    icon: Icons.donut_small_rounded,
  ),
  Destination(
    space: NavSpace.money,
    label: 'Cartões e faturas',
    short: 'Faturas',
    icon: Icons.credit_card_rounded,
  ),
  Destination(
    space: NavSpace.future,
    label: 'Projeção',
    icon: Icons.trending_up_rounded,
  ),
  Destination(
    space: NavSpace.settings,
    label: 'Mais',
    icon: Icons.more_horiz_rounded,
  ),
];

/// The desktop navigation.
///
/// Not a `NavigationRail`. The rail was handed the same five destinations as
/// the phone's bottom bar — a Material limit written for a 360pt screen, which
/// is why "Mais" survived onto a 27-inch monitor. Here every destination is
/// visible and the spaces are separated by rules.
class LedgerSidebar extends StatelessWidget {
  const LedgerSidebar({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelected,
    required this.compact,
    this.header,
    this.footer,
  });

  final List<Destination> items;
  final int selected;
  final ValueChanged<int> onSelected;

  /// Icons only, for the middle widths.
  final bool compact;

  final Widget? header;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final rows = <Widget>[];
    NavSpace? group;

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (item.space != group) {
        group = item.space;
        if (!compact) {
          rows.add(
            Padding(
              padding: EdgeInsets.only(
                left: Space.md,
                right: Space.md,
                top: rows.isEmpty ? 0 : Space.md,
                bottom: Space.xxs,
              ),
              child: SectionLabel(item.space.label),
            ),
          );
        } else if (rows.isNotEmpty) {
          rows.add(
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Space.sm,
                vertical: Space.xs,
              ),
              child: Divider(height: 1, color: palette.rule),
            ),
          );
        }
      }
      rows.add(
        _SidebarItem(
          item: item,
          selected: i == selected,
          compact: compact,
          onTap: () => onSelected(i),
        ),
      );
    }

    return Container(
      width: compact ? 68 : 216,
      decoration: BoxDecoration(
        color: palette.canvas,
        border: Border(
          right: BorderSide(color: palette.rule, width: Strokes.hairline),
        ),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (header != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.sm,
                  Space.md,
                  Space.sm,
                  Space.sm,
                ),
                child: header!,
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: Space.md),
                children: rows,
              ),
            ),
            if (footer != null)
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: palette.rule,
                      width: Strokes.hairline,
                    ),
                  ),
                ),
                padding: const EdgeInsets.all(Space.xs),
                child: footer,
              ),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.item,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final Destination item;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final content = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? Space.xs : Space.sm,
        vertical: Space.xs,
      ),
      decoration: BoxDecoration(
        color: selected ? palette.sunken : null,
        border: Border(
          // The active mark is a rule in pen ink down the left edge, not a
          // filled pill.
          left: BorderSide(
            color: selected ? palette.accent : Colors.transparent,
            width: 2,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: compact
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        children: [
          Icon(
            item.icon,
            size: 18,
            color: selected ? palette.accent : palette.inkSubtle,
          ),
          if (!compact) ...[
            const SizedBox(width: Space.sm),
            Expanded(
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.type.bodySm.copyWith(
                  color: selected ? palette.ink : palette.inkMuted,
                  fontWeight: selected ? FontWeight.w600 : null,
                ),
              ),
            ),
          ],
          if (item.badge > 0) ...[
            if (!compact) const SizedBox(width: Space.xxs),
            _Badge(count: item.badge),
          ],
        ],
      ),
    );

    return Semantics(
      selected: selected,
      button: true,
      label: item.badge > 0
          ? '${item.label}, ${item.badge} aguardando'
          : item.label,
      child: Tooltip(
        message: compact ? item.label : '',
        child: InkWell(onTap: onTap, child: content),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: palette.negative,
        borderRadius: BorderRadius.circular(Radii.xs),
      ),
      child: Text(
        '$count',
        style: context.type.labelCaps.copyWith(
          fontSize: 9.5,
          letterSpacing: 0.4,
          color: palette.canvas,
        ),
      ),
    );
  }
}

/// The phone navigation.
///
/// Five destinations, the middle one being the action rather than a screen —
/// which retires the floating button that used to cover the last row of every
/// list. The active mark is a rule of pen ink at the top, not a filled pill.
class LedgerTabBar extends StatelessWidget {
  const LedgerTabBar({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelected,
    this.onCreate,
  });

  final List<Destination> items;
  final int selected;
  final ValueChanged<int> onSelected;

  /// Null while the ledger has not arrived: a new transaction needs the
  /// categories and cards to choose from. The tab stays, greyed, rather than
  /// the bar disappearing — a navigation that vanishes during a refresh is one
  /// that cannot be trusted.
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final slots = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i == 2) slots.add(_CreateTab(onTap: onCreate));
      slots.add(
        _Tab(
          item: items[i],
          selected: i == selected,
          onTap: () => onSelected(i),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: palette.canvas,
        border: Border(
          top: BorderSide(color: palette.rule, width: Strokes.hairline),
        ),
      ),
      child: SafeArea(top: false, child: Row(children: slots)),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.item, required this.selected, required this.onTap});
  final Destination item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        label: item.badge > 0
            ? '${item.label}, ${item.badge} aguardando'
            : item.label,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.only(top: 7, bottom: 5),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: selected ? palette.accent : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      item.icon,
                      size: 19,
                      color: selected ? palette.ink : palette.inkSubtle,
                    ),
                    if (item.badge > 0)
                      Positioned(
                        top: -4,
                        right: -8,
                        child: _Badge(count: item.badge),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  item.short,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.type.labelCaps.copyWith(
                    fontSize: 8.5,
                    letterSpacing: 0.6,
                    color: selected ? palette.ink : palette.inkSubtle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CreateTab extends StatelessWidget {
  const _CreateTab({required this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final enabled = onTap != null;
    return Expanded(
      child: Semantics(
        button: true,
        enabled: enabled,
        label: 'Novo lançamento',
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            // `heightFactor: 1` is what stops this sizing to the constraints it
            // is offered. Without it `Center` expanded to the full screen
            // height, took the whole `Row` with it, and left the body with
            // nothing — the bar rendered halfway down the screen with the page
            // squeezed to zero. It only shows on a phone, which is the one
            // width whose shell golden I generated and never looked at.
            child: Center(
              heightFactor: 1,
              child: Container(
                width: 40,
                height: 28,
                decoration: BoxDecoration(
                  // Dimmed rather than hidden while the ledger loads: the
                  // action still exists, it just has nothing to choose from
                  // yet.
                  color: enabled ? palette.action : palette.rule,
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
                child: Icon(
                  Icons.add,
                  size: 18,
                  color: enabled ? palette.onAction : palette.inkSubtle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
