import 'package:financeiro_ai/application/reminder_service.dart';
import 'package:financeiro_ai/core/theme.dart';
import 'package:financeiro_ai/domain/models.dart';
import 'package:financeiro_ai/domain/reminders.dart';
import 'package:financeiro_ai/presentation/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Turns invoice due dates into notifications on this phone.
class RemindersPage extends ConsumerStatefulWidget {
  const RemindersPage({super.key, required this.snapshot});
  final FinanceSnapshot snapshot;

  @override
  ConsumerState<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends ConsumerState<RemindersPage> {
  ReminderSettings? _settings;
  bool _busy = false;

  /// Set when the person turned reminders on but the system prompt came back
  /// denied — without this the switch would sit on while nothing would fire.
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await ref.read(reminderServiceProvider).loadSettings();
    if (mounted) setState(() => _settings = settings);
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;

    return Scaffold(
      appBar: AppBar(title: const Text('Lembretes')),
      body: settings == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
              children: [
                if (!ReminderService.isSupported)
                  _Note(
                    text:
                        'Lembretes só funcionam no aplicativo do celular. Esta '
                        'sessão está no navegador, onde o aviso dependeria da '
                        'aba continuar aberta.',
                    color: context.palette.inkMuted,
                  )
                else ...[
                  Card(
                    child: SwitchListTile(
                      value: settings.enabled,
                      title: const Text(
                        'Avisar antes do vencimento',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        'Uma notificação por fatura em aberto.',
                        style: TextStyle(color: context.palette.inkMuted),
                      ),
                      onChanged: _busy ? null : _toggle,
                    ),
                  ),
                  if (_permissionDenied)
                    _Note(
                      text:
                          'As notificações estão bloqueadas para o Finora. '
                          'Libere em Ajustes › Notificações e volte aqui.',
                      color: context.palette.negative,
                    ),
                  const SizedBox(height: 20),
                  _Section(
                    title: 'Quantos dias antes',
                    child: Wrap(
                      spacing: 8,
                      children: [1, 3, 5, 7]
                          .map(
                            (days) => ChoiceChip(
                              label: Text(days == 1 ? '1 dia' : '$days dias'),
                              selected: settings.daysBefore == days,
                              onSelected: settings.enabled && !_busy
                                  ? (_) => _apply(
                                      settings.copyWith(daysBefore: days),
                                    )
                                  : null,
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _Section(
                    title: 'A que horas',
                    child: Wrap(
                      spacing: 8,
                      children: [9, 12, 18, 20]
                          .map(
                            (hour) => ChoiceChip(
                              label: Text(
                                '${hour.toString().padLeft(2, '0')}:00',
                              ),
                              selected: settings.hour == hour,
                              onSelected: settings.enabled && !_busy
                                  ? (_) => _apply(settings.copyWith(hour: hour))
                                  : null,
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _Preview(snapshot: widget.snapshot, settings: settings),
                ],
              ],
            ),
    );
  }

  Future<void> _toggle(bool value) async {
    final service = ref.read(reminderServiceProvider);
    setState(() => _busy = true);

    if (value) {
      // Asking here, rather than at launch, means the system prompt arrives
      // right after the person said what it is for.
      final granted = await service.requestPermission();
      if (!granted) {
        if (mounted) {
          setState(() {
            _busy = false;
            _permissionDenied = true;
          });
        }
        return;
      }
    }

    await _apply(
      _settings!.copyWith(enabled: value),
      clearPermissionWarning: true,
    );
  }

  Future<void> _apply(
    ReminderSettings settings, {
    bool clearPermissionWarning = false,
  }) async {
    final service = ref.read(reminderServiceProvider);
    setState(() {
      _settings = settings;
      _busy = true;
      if (clearPermissionWarning) _permissionDenied = false;
    });

    await service.saveSettings(settings);
    final scheduled = await service.sync(
      widget.snapshot,
      settings,
      money: currency.format,
    );

    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          !settings.enabled
              ? 'Lembretes desligados.'
              : scheduled == 0
              ? 'Nenhuma fatura em aberto para avisar por enquanto.'
              : scheduled == 1
              ? '1 lembrete agendado.'
              : '$scheduled lembretes agendados.',
        ),
      ),
    );
  }
}

/// What the current choice would actually schedule.
///
/// Shown because everything else on this screen is a promise about the future:
/// without the list, the only way to find out whether anything was scheduled
/// would be to wait for the day to arrive.
class _Preview extends StatelessWidget {
  const _Preview({required this.snapshot, required this.settings});
  final FinanceSnapshot snapshot;
  final ReminderSettings settings;

  @override
  Widget build(BuildContext context) {
    if (!settings.enabled) {
      return _Note(
        text:
            'Com os lembretes ligados, o Finora avisa antes de cada fatura em '
            'aberto vencer.',
        color: context.palette.inkMuted,
      );
    }

    final reminders = dueReminders(
      snapshot,
      daysBefore: settings.daysBefore,
      hour: settings.hour,
    );

    if (reminders.isEmpty) {
      return _Note(
        text:
            'Nada agendado: não há fatura em aberto cujo aviso ainda esteja no '
            'futuro. Assim que a próxima fechar, o lembrete aparece aqui.',
        color: context.palette.inkMuted,
      );
    }

    return _Section(
      title: 'O que está agendado',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: reminders
            .map(
              (reminder) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.notifications_active_rounded,
                      size: 18,
                      color: context.palette.accent,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            reminderTitle(reminder),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${longDate.format(reminder.fireAt)} às '
                            '${reminder.fireAt.hour.toString().padLeft(2, '0')}:00'
                            ' · ${currency.format(reminder.total)}',
                            style: TextStyle(
                              color: context.palette.inkSubtle,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 12),
      child,
    ],
  );
}

class _Note extends StatelessWidget {
  const _Note({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(text, style: TextStyle(color: color, height: 1.45)),
  );
}
