import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'prayer_service.dart';

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

  Future<void> init() async {
    if (_initialized) return;
    if (kIsWeb) {
      _initialized = true;
      return;
    }

    tz_data.initializeTimeZones();
    // BUG-003 fix: use device's local timezone instead of hardcoded 'Asia/Dubai'
    tz.setLocalLocation(tz.local);

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

    // BUG-016 fix: removed redundant !kIsWeb guard; init() already returns early on web
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    _initialized = true;
  }

  Future<void> scheduleSessionNotifications({
    required bool sessionRemindersEnabled,
    required bool prayerAlertsEnabled,
    Set<String> disabledSessionIds = const {},
  }) async {
    if (kIsWeb) return;
    await _plugin.cancelAll();
    final now = DateTime.now();
    int notifId = 100;

    if (sessionRemindersEnabled) {
      for (final s in _sessionSchedule) {
        if (disabledSessionIds.contains(s.id)) continue;
        final start = _parseTime(s.startStr, now);
        if (start == null) continue;
        DateTime remind = start.subtract(const Duration(minutes: 15));
        if (remind.isBefore(now)) remind = remind.add(const Duration(days: 1));
        await _zoned(
          id: notifId++,
          title: '${s.name} starts in 15 min',
          body: s.body,
          when: remind,
        );
      }
    }

    if (prayerAlertsEnabled) {
      final prayers = prayerService.getTodayPrayerTimes();
      for (final p in [('Fajr', prayers.fajr), ('Asr', prayers.asr)]) {
        DateTime alertTime = p.$2.subtract(const Duration(minutes: 10));
        if (alertTime.isBefore(now)) alertTime = alertTime.add(const Duration(days: 1));
        await _zoned(
          id: notifId++,
          title: '${p.$1} in 10 minutes',
          body: 'Prepare for prayer.',
          when: alertTime,
        );
      }
    }
  }

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
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (_) {
    }
  }

  Future<void> cancelAll() => _plugin.cancelAll();

  DateTime? _parseTime(String t, DateTime ref) {
    try {
      t = t.toLowerCase().replaceAll(' ', '');
      if (t == 'allday' || t.isEmpty) return null;
      final isPm = t.contains('pm');
      t = t.replaceAll('pm', '').replaceAll('am', '');
      final p = t.split(':');
      int h = int.tryParse(p[0]) ?? 0;
      final m = p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0;
      if (isPm && h != 12) h += 12;
      if (!isPm && h == 12) h = 0;
      return DateTime(ref.year, ref.month, ref.day, h, m);
    } catch (_) {
      return null;
    }
  }

  static const _sessionSchedule = [
    _S('morning', 'Morning', '5:00am', 'Morning habits time.'),
    _S('afternoon', 'Afternoon', '12:00pm', 'Afternoon build session.'),
    _S('evening', 'Evening', '4:00pm', 'Evening wind-down.'),
    _S('night', 'Night', '7:00pm', 'Night routine.'),
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
