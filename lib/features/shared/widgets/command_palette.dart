import 'package:financeiro_ai/core/theme/theme.dart';
import 'package:financeiro_ai/core/theme/tokens.dart';
import 'package:financeiro_ai/core/theme/typography.dart';
import 'package:financeiro_ai/core/design_system/ledger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// One thing someone can do, reachable by name.
class Command {
  const Command({
    required this.label,
    required this.run,
    this.group = '',
    this.hint,
    this.icon,
  });

  final String label;
  final VoidCallback run;
  final String group;

  /// The shortcut, when there is one.
  final String? hint;
  final IconData? icon;

  bool matches(String query) {
    if (query.isEmpty) return true;
    final needle = query.toLowerCase();
    return label.toLowerCase().contains(needle) ||
        group.toLowerCase().contains(needle);
  }
}

/// ⌘K.
///
/// The product had no keyboard affordance at all — not one `Shortcuts` widget
/// in the codebase. In something built around entering and reviewing the same
/// kinds of row over and over, the keyboard *is* the desktop interface, and its
/// absence changes how the whole thing feels more than any single visual
/// choice.
Future<void> showCommandPalette(
  BuildContext context, {
  required List<Command> commands,
}) => showDialog<void>(
  context: context,
  barrierColor: Colors.black.withValues(alpha: .32),
  builder: (context) => _Palette(commands: commands),
);

class _Palette extends StatefulWidget {
  const _Palette({required this.commands});
  final List<Command> commands;

  @override
  State<_Palette> createState() => _PaletteState();
}

class _PaletteState extends State<_Palette> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  int _cursor = 0;

  List<Command> get _matches =>
      widget.commands.where((c) => c.matches(_controller.text)).toList();

  @override
  void initState() {
    super.initState();
    _focus.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _move(int delta) {
    final list = _matches;
    if (list.isEmpty) return;
    setState(() => _cursor = (_cursor + delta) % list.length);
    if (_cursor < 0) setState(() => _cursor = list.length - 1);
  }

  void _run() {
    final list = _matches;
    if (list.isEmpty) return;
    final command = list[_cursor.clamp(0, list.length - 1)];
    Navigator.of(context).pop();
    command.run();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final list = _matches;

    return Align(
      alignment: const Alignment(0, -0.4),
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowDown): () => _move(1),
          const SingleActivator(LogicalKeyboardKey.arrowUp): () => _move(-1),
          // The same pair as the review queue, so one habit covers both.
          const SingleActivator(LogicalKeyboardKey.keyJ, control: true): () =>
              _move(1),
          const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
              _move(-1),
          const SingleActivator(LogicalKeyboardKey.enter): _run,
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              Navigator.of(context).maybePop(),
        },
        child: Material(
          color: palette.canvas,
          borderRadius: BorderRadius.circular(Radii.md),
          child: Container(
            width: 520,
            constraints: const BoxConstraints(maxHeight: 420),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(color: palette.ruleStrong),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Space.md,
                    Space.sm,
                    Space.sm,
                    Space.sm,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        size: 18,
                        color: palette.inkSubtle,
                      ),
                      const SizedBox(width: Space.xs),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: _focus,
                          autofocus: true,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            isDense: true,
                            hintText: 'Buscar tela ou comando',
                          ),
                          onChanged: (_) => setState(() => _cursor = 0),
                          onSubmitted: (_) => _run(),
                        ),
                      ),
                      const MonoTag('esc'),
                    ],
                  ),
                ),
                Divider(height: 1, color: palette.rule),
                Flexible(
                  child: list.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(Space.xl),
                          child: Text(
                            'Nada com esse nome.',
                            style: context.type.bodySm.copyWith(
                              color: palette.inkSubtle,
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: list.length,
                          itemBuilder: (context, index) {
                            final command = list[index];
                            final active = index == _cursor;
                            return InkWell(
                              onTap: () {
                                Navigator.of(context).pop();
                                command.run();
                              },
                              onHover: (over) {
                                if (over) setState(() => _cursor = index);
                              },
                              child: Container(
                                color: active ? palette.accentSoft : null,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: Space.md,
                                  vertical: Space.xs,
                                ),
                                child: Row(
                                  children: [
                                    if (command.icon != null) ...[
                                      Icon(
                                        command.icon,
                                        size: 16,
                                        color: active
                                            ? palette.accent
                                            : palette.inkSubtle,
                                      ),
                                      const SizedBox(width: Space.sm),
                                    ],
                                    Expanded(
                                      child: Text(
                                        command.label,
                                        style: context.type.bodySm,
                                      ),
                                    ),
                                    if (command.group.isNotEmpty)
                                      Text(
                                        command.group,
                                        style: context.type.meta.copyWith(
                                          color: palette.inkSubtle,
                                        ),
                                      ),
                                    if (command.hint != null) ...[
                                      const SizedBox(width: Space.xs),
                                      MonoTag(command.hint!),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
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
