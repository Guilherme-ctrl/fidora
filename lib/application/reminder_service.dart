import 'package:financeiro_ai/domain/models.dart';
import 'package:financeiro_ai/domain/reminders.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Local reminders for invoices coming due.
///
/// The preference lives on the device rather than in `profiles`: whether this
/// phone should buzz is a property of the phone, not of the account, and a web
/// session has no business turning the iPhone's notifications off.
class ReminderService {
  ReminderService(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  static const _enabledKey = 'reminders.enabled';
  static const _daysKey = 'reminders.days_before';
  static const _hourKey = 'reminders.hour';

  static const defaultDaysBefore = 3;
  static const defaultHour = 9;

  bool _ready = false;

  /// Notifications are a mobile affordance; the web build has no equivalent and
  /// calling the plugin there throws.
  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  Future<void> _ensureReady() async {
    if (_ready || !isSupported) return;
    tzdata.initializeTimeZones();
    // The Shortcut and the whole ledger are built around São Paulo; scheduling
    // in UTC would fire the reminder at the wrong hour of the day.
    tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
    await _plugin.initialize(
      settings: const InitializationSettings(
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _ready = true;
  }

  /// Asks the person, once they have chosen to turn reminders on — rather than
  /// at launch, when there is nothing to explain the prompt.
  Future<bool> requestPermission() async {
    if (!isSupported) return false;
    await _ensureReady();
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return granted ?? false;
    }
    final granted = await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    return granted ?? false;
  }

  Future<ReminderSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return ReminderSettings(
      enabled: prefs.getBool(_enabledKey) ?? false,
      daysBefore: prefs.getInt(_daysKey) ?? defaultDaysBefore,
      hour: prefs.getInt(_hourKey) ?? defaultHour,
    );
  }

  Future<void> saveSettings(ReminderSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, settings.enabled);
    await prefs.setInt(_daysKey, settings.daysBefore);
    await prefs.setInt(_hourKey, settings.hour);
  }

  /// Replaces every scheduled reminder with the current set.
  ///
  /// Cancelling first is what keeps a paid or re-dated invoice from buzzing:
  /// adding without clearing would leave the old notification in place.
  ///
  /// [money] comes from the caller rather than being hardcoded here, so the
  /// notification uses the same currency the rest of the app resolved from the
  /// profile instead of assuming reais.
  Future<int> sync(
    FinanceSnapshot snapshot,
    ReminderSettings settings, {
    required String Function(double) money,
  }) async {
    if (!isSupported) return 0;
    await _ensureReady();
    await _plugin.cancelAll();
    if (!settings.enabled) return 0;

    final reminders = dueReminders(
      snapshot,
      daysBefore: settings.daysBefore,
      hour: settings.hour,
    );
    for (final reminder in reminders) {
      await _plugin.zonedSchedule(
        id: reminder.notificationId,
        title: reminderTitle(reminder),
        body: reminderBody(reminder, money),
        scheduledDate: tz.TZDateTime.from(reminder.fireAt, tz.local),
        notificationDetails: const NotificationDetails(
          iOS: DarwinNotificationDetails(),
          android: AndroidNotificationDetails(
            'invoice_due',
            'Vencimento de fatura',
            channelDescription: 'Aviso alguns dias antes de a fatura vencer.',
            importance: Importance.defaultImportance,
          ),
        ),
        // A due-date warning is useful within the hour, not to the second, and
        // an exact alarm would need a separate permission on Android 12+.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
    return reminders.length;
  }
}

ReminderService defaultReminderService() =>
    ReminderService(FlutterLocalNotificationsPlugin());

class ReminderSettings {
  const ReminderSettings({
    required this.enabled,
    required this.daysBefore,
    required this.hour,
  });

  final bool enabled;
  final int daysBefore;
  final int hour;

  ReminderSettings copyWith({bool? enabled, int? daysBefore, int? hour}) =>
      ReminderSettings(
        enabled: enabled ?? this.enabled,
        daysBefore: daysBefore ?? this.daysBefore,
        hour: hour ?? this.hour,
      );
}
