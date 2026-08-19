import 'package:financeiro_ai/application/reminder_service.dart';
import 'package:financeiro_ai/core/theme.dart';
import 'package:financeiro_ai/domain/models.dart';
import 'package:financeiro_ai/presentation/pages/reminders_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Stands in for the real service so the screen can be driven without a
/// notification channel: everything the page does with it is recorded instead
/// of scheduled.
class _FakeReminderService extends ReminderService {
  _FakeReminderService({this.grant = true})
    : super(FlutterLocalNotificationsPlugin());

  final bool grant;

  ReminderSettings stored = const ReminderSettings(
    enabled: false,
    daysBefore: 3,
    hour: 9,
  );
  final syncs = <ReminderSettings>[];
  int permissionRequests = 0;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return grant;
  }

  @override
  Future<ReminderSettings> loadSettings() async => stored;

  @override
  Future<void> saveSettings(ReminderSettings settings) async {
    stored = settings;
  }

  @override
  Future<int> sync(
    FinanceSnapshot snapshot,
    ReminderSettings settings, {
    required String Function(double) money,
  }) async {
    syncs.add(settings);
    return settings.enabled ? 1 : 0;
  }
}

FinanceSnapshot _snapshot() => FinanceSnapshot(
  transactions: const [],
  categories: const [],
  cards: [
    CreditCard(
      id: 'card-1',
      name: 'Nubank',
      bank: 'Nu',
      lastFour: '1234',
      limit: 5000,
      closingDay: 20,
      dueDay: 27,
      holder: 'Você',
    ),
  ],
  invoices: [
    Invoice(
      id: 'inv-1',
      cardId: 'card-1',
      // Far enough out that the reminder still lies ahead whenever this runs.
      referenceMonth: DateTime(DateTime.now().year + 1),
      total: 1200,
      dueDate: DateTime.now().add(const Duration(days: 40)),
      status: 'open',
    ),
  ],
  goals: const [],
  pendingReviews: 0,
);

Future<void> _pump(WidgetTester tester, _FakeReminderService service) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [reminderServiceProvider.overrideWithValue(service)],
      child: MaterialApp(
        theme: buildAppTheme(brightness: Brightness.light),
        home: RemindersPage(snapshot: _snapshot()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  testWidgets('starts off and explains what turning it on would do', (
    tester,
  ) async {
    final service = _FakeReminderService();
    await _pump(tester, service);

    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse);
    expect(find.textContaining('avisa antes de cada fatura'), findsOneWidget);
    expect(service.syncs, isEmpty);
  });

  testWidgets('asks for permission before scheduling anything', (tester) async {
    final service = _FakeReminderService();
    await _pump(tester, service);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(service.permissionRequests, 1);
    expect(service.stored.enabled, isTrue);
    expect(service.syncs.single.enabled, isTrue);
    expect(find.text('1 lembrete agendado.'), findsOneWidget);
  });

  testWidgets('leaves the switch off when permission is refused', (
    tester,
  ) async {
    final service = _FakeReminderService(grant: false);
    await _pump(tester, service);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    // The point of the guard: nothing was scheduled and nothing was saved, so
    // the switch cannot sit on while the system stays silent.
    expect(service.syncs, isEmpty);
    expect(service.stored.enabled, isFalse);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );
    expect(find.textContaining('estão bloqueadas'), findsOneWidget);
  });

  testWidgets('reschedules when the number of days changes', (tester) async {
    final service = _FakeReminderService();
    service.stored = const ReminderSettings(
      enabled: true,
      daysBefore: 3,
      hour: 9,
    );
    await _pump(tester, service);

    await tester.tap(find.widgetWithText(ChoiceChip, '7 dias'));
    await tester.pumpAndSettle();

    expect(service.stored.daysBefore, 7);
    expect(service.syncs.single.daysBefore, 7);
    // Turning a knob must not re-prompt: permission was already granted.
    expect(service.permissionRequests, 0);
  });

  testWidgets('reschedules when the hour changes', (tester) async {
    final service = _FakeReminderService();
    service.stored = const ReminderSettings(
      enabled: true,
      daysBefore: 3,
      hour: 9,
    );
    await _pump(tester, service);

    await tester.tap(find.widgetWithText(ChoiceChip, '20:00'));
    await tester.pumpAndSettle();

    expect(service.stored.hour, 20);
    expect(service.syncs.single.hour, 20);
  });

  testWidgets('previews the reminder that is actually scheduled', (
    tester,
  ) async {
    final service = _FakeReminderService();
    service.stored = const ReminderSettings(
      enabled: true,
      daysBefore: 3,
      hour: 9,
    );
    await _pump(tester, service);

    expect(find.text('O que está agendado'), findsOneWidget);
    expect(find.textContaining('Fatura Nubank vence em 3 dias'), findsOneWidget);
  });

  testWidgets('the knobs are inert while reminders are off', (tester) async {
    final service = _FakeReminderService();
    await _pump(tester, service);

    final chip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, '7 dias'),
    );
    expect(chip.onSelected, isNull);
  });
}
