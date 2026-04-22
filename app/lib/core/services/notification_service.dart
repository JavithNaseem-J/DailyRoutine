import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'prayer_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NotificationService — flutter_local_notifications v20.x
//
// v20 API: ALL top-level methods use named parameters.
//   initialize(settings: ..., ...)
//   zonedSchedule(id:, scheduledDate:, notificationDetails:,
//                 androidScheduleMode:, title:, body:)
// ─────────────────────────────────────────────────────────────────────────────

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _channelId = 'routine_channel';

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      'Daily Routine',
      channelDescription: 'Session and prayer reminders',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  // ── Init ───────────────────────────────────────────────────────────
  Future<void> init() async {
    if (_initialized) return;
    if (kIsWeb) {
      _initialized = true;
      return; // flutter_local_notifications doesn't support web natively or throws errors
    }

    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Dubai'));

    // v20: named `settings:` param
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        ),
      ),
    );

    if (!kIsWeb) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    }

    _initialized = true;
  }

  // ── Schedule all reminders for today ──────────────────────────────
  Future<void> scheduleSessionNotifications({
    required bool sessionRemindersEnabled,
    required bool prayerAlertsEnabled,
    Set<String> disabledSessionIds = const {},
  }) async {
    if (kIsWeb) return; // Prevent crashes on web
    await _plugin.cancelAll();
    final now = DateTime.now();
    int notifId = 100;

    // Session reminders — 15 min before each session
    if (sessionRemindersEnabled) {
      for (final s in _sessionSchedule) {
        if (disabledSessionIds.contains(s.id)) continue;
        final start = _parseTime(s.startStr, now);
        if (start == null) continue;
        final remind = start.subtract(const Duration(minutes: 15));
        if (remind.isAfter(now)) {
          await _zoned(
            id: notifId++,
            title: '${s.name} starts in 15 min',
            body: s.body,
            when: remind,
          );
        }
      }
    }

    // Prayer alerts — 10 min before Fajr + Asr
    if (prayerAlertsEnabled) {
      final prayers = prayerService.getTodayPrayerTimes();
      for (final p in [('Fajr', prayers.fajr), ('Asr', prayers.asr)]) {
        final alertTime = p.$2.subtract(const Duration(minutes: 10));
        if (alertTime.isAfter(now)) {
          await _zoned(
            id: notifId++,
            title: '${p.$1} in 10 minutes',
            body: 'Prepare for prayer.',
            when: alertTime,
          );
        }
      }
    }
  }

  // ── v20 zonedSchedule (all named params) ──────────────────────────
  Future<void> _zoned({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(when, tz.local),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (_) {
      // Exact alarm permission may not be granted — degrade silently
    }
  }

  // ── Cancel all ─────────────────────────────────────────────────────
  Future<void> cancelAll() => _plugin.cancelAll();

  // ── Helpers ────────────────────────────────────────────────────────
  DateTime? _parseTime(String t, DateTime ref) {
    try {
      t = t.toLowerCase().replaceAll(' ', '');
      final isPm = t.contains('pm');
      t = t.replaceAll('pm', '').replaceAll('am', '');
      final p = t.split(':');
      int h = int.parse(p[0]);
      final m = p.length > 1 ? int.parse(p[1]) : 0;
      if (isPm && h != 12) h += 12;
      if (!isPm && h == 12) h = 0;
      return DateTime(ref.year, ref.month, ref.day, h, m);
    } catch (_) {
      return null;
    }
  }

  static const _sessionSchedule = [
    _S('dawn', 'Dawn (Fajr)', '4:30am', 'Start your morning devotion.'),
    _S('sunrise', 'Sunrise Build', '6:30am', 'First deep-work session.'),
    _S('morning', 'Morning', '8:30am', 'Morning habits time.'),
    _S('midMorning', 'Mid Morning Build', '10:00am', 'Second build session.'),
    _S('midday', 'Midday', '12:00pm', 'Midday check-in.'),
    _S('afternoon', 'Afternoon Build', '2:00pm', 'Third build session.'),
    _S('asr', 'Asr', '4:30pm', 'Asr prayer and wind-down.'),
    _S('sunset', 'Sunset', '6:00pm', 'Sunset reflection.'),
    _S('evening', 'Evening', '7:30pm', 'Evening wind-down.'),
    _S('night', 'Night', '9:00pm', 'Night routine.'),
  ];
}

class _S {
  const _S(this.id, this.name, this.startStr, this.body);
  final String id;
  final String name;
  final String startStr;
  final String body;
}

final notificationService = NotificationService();
