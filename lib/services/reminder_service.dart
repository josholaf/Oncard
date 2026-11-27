import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/app_data.dart';
import '../data/daily_quotes.dart';
import '../data/reminder_settings.dart';

/// Schedules and presents the daily revision reminder.
///
/// All scheduling is idempotent: [apply] cancels any pending reminder before
/// scheduling, so it is safe to call on every app start and every settings
/// change. Scheduling failures never crash the app; the reminder is simply
/// not armed and the next call retries.
class ReminderService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static const int _id = 100;
  static const String _channelId = 'oncard_reminders';
  static const String _channelName = 'Daily revision reminders';
  static const String _payloadPrefix = 'deck:';

  /// Called with the tapped notification payload (a deck id), both for taps
  /// while the app runs and for the cold-start launch payload. Set by main.
  static void Function(String deckId)? onTap;

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload ?? '';
        if (payload.startsWith(_payloadPrefix)) {
          onTap?.call(payload.substring(_payloadPrefix.length));
        }
      },
    );
    _initialized = true;
  }

  /// Requests the Android 13+ runtime permission. Returns true when granted
  /// (or when the platform does not need a request).
  static Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission();
    return granted ?? true;
  }

  /// Cancels any pending reminder and, when enabled, schedules the next one.
  static Future<void> apply(AppData data) async {
    if (!_initialized) return;
    await _plugin.cancel(_id);
    final s = data.reminder;
    if (!s.enabled) return;
    try {
      final now = DateTime.now();
      var next = DateTime(now.year, now.month, now.day, s.hour, s.minute);
      if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
      // The first fire is computed in UTC from the device's current offset,
      // so it lands on the user's chosen wall-clock time. Rwanda and most
      // target regions have no DST; the daily re-apply on app start
      // self-heals any offset change for regions that do.
      final tzTime = tz.TZDateTime.utc(next.year, next.month, next.day,
              next.hour, next.minute)
          .subtract(now.timeZoneOffset);
      final content = buildContent(data);
      await _plugin.zonedSchedule(
        _id,
        content.title,
        content.body,
        tzTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: 'A daily nudge to revise your flashcards',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
        ),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: content.deckId == null
            ? null
            : _payloadPrefix + content.deckId!,
      );
    } catch (e) {
      debugPrint('ReminderService.apply failed: ' + e.toString());
    }
  }

  /// Shows the reminder immediately, so users can preview it in Settings.
  static Future<void> showTest(AppData data) async {
    if (!_initialized) return;
    final content = buildContent(data);
    await _plugin.show(
      _id,
      content.title,
      content.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'A daily nudge to revise your flashcards',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      payload: content.deckId == null
          ? null
          : _payloadPrefix + content.deckId!,
    );
  }

  /// Handles the cold-start case: the app was launched by a notification tap.
  static Future<void> handleLaunch() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return;
    final payload = details?.notificationResponse?.payload ?? '';
    if (payload.startsWith(_payloadPrefix)) {
      onTap?.call(payload.substring(_payloadPrefix.length));
    }
  }

  static _NotificationContent buildContent(AppData data) {
    final quote = quoteForDay(DateTime.now());
    final question = dueQuestion(data.decks);
    final deck = deckOfTheDay(data.decks);
    final title = 'Time to revise';
    if (question == null || question.trim().isEmpty) {
      return _NotificationContent(
          title: title, body: quote, deckId: deck?.id);
    }
    final q = question.trim();
    final short = q.length > 90 ? q.substring(0, 87) + '...' : q;
    return _NotificationContent(
      title: title,
      body: '"' + short + '"\n' + quote,
      deckId: deck?.id,
    );
  }
}

class _NotificationContent {
  final String title;
  final String body;
  final String? deckId;
  const _NotificationContent(
      {required this.title, required this.body, this.deckId});
}
