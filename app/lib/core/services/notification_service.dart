import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'prayer_service.dart';
import '../../app.dart';

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
      onDidReceiveNotificationResponse: (response) {
        if (response.payload != null && response.payload!.startsWith('focus|')) {
          final parts = response.payload!.split('|');
          if (parts.length >= 2) {
            appRouter.push('/focus', extra: {
              'taskTitle': parts[1],
            });
          }
        }
      },
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
    Map<String, bool> prayerEnabled = const {},   // per-prayer ON/OFF
    Map<String, int> prayerOffset = const {},     // per-prayer minutes after adhan
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
      final allPrayers = [
        ('Fajr',    prayers.fajr,    '🌅', 'The adhan was called — it\'s time to pray Fajr.'),
        ('Dhuhr',   prayers.dhuhr,   '☀️',  'It\'s Dhuhr time. Step away and pray.'),
        ('Asr',     prayers.asr,     '🌤️', 'Asr is here. Don\'t delay your prayer.'),
        ('Maghrib', prayers.maghrib, '🌇', 'The sun has set — pray Maghrib now.'),
        ('Isha',    prayers.isha,    '🌙', 'Isha time. End your day with prayer.'),
      ];
      for (final p in allPrayers) {
        final key = p.$1.toLowerCase();
        // Skip if this prayer is individually disabled
        if (prayerEnabled.containsKey(key) && prayerEnabled[key] == false) continue;
        // Use per-prayer offset (default 10 min after adhan)
        final offset = prayerOffset[key] ?? 10;
        DateTime alertTime = p.$2.add(Duration(minutes: offset));
        if (alertTime.isBefore(now)) alertTime = alertTime.add(const Duration(days: 1));
        await _zoned(
          id: notifId++,
          title: '${p.$3} ${p.$1} — Time to Pray',
          body: p.$4,
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

  Future<void> scheduleFocusAlarm(String taskTitle, DateTime endTime) async {
    if (kIsWeb) return;
    try {
      await _plugin.zonedSchedule(
        id: 999,
        title: 'Focus Complete!',
        body: 'You have finished: $taskTitle',
        scheduledDate: tz.TZDateTime.from(endTime, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'focus_channel',
            'Focus Timers',
            channelDescription: 'Alarm for focus sessions',
            importance: Importance.max,
            priority: Priority.max,
            sound: RawResourceAndroidNotificationSound('timer_done'),
            playSound: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            sound: 'timer_done.wav',
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (_) {}
  }

  Future<void> cancelFocusAlarm() async {
    if (kIsWeb) return;
    await _plugin.cancel(id: 999);
  }

  Future<void> showOngoingFocus(String taskTitle) async {
    if (kIsWeb) return;
    try {
      await _plugin.show(
        id: 998,
        title: 'Focus Timer Active',
        body: taskTitle,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'focus_ongoing_channel',
            'Active Focus',
            channelDescription: 'Ongoing focus timer',
            importance: Importance.low,
            priority: Priority.low,
            ongoing: true,
            autoCancel: false,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: false,
            presentBadge: false,
            presentSound: false,
          ),
        ),
        payload: 'focus|$taskTitle',
      );
    } catch (_) {}
  }

  Future<void> showOngoingFocusPaused(String taskTitle) async {
    if (kIsWeb) return;
    try {
      await _plugin.show(
        id: 998,
        title: 'Focus Timer Paused',
        body: taskTitle,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'focus_ongoing_channel',
            'Active Focus',
            channelDescription: 'Ongoing focus timer',
            importance: Importance.low,
            priority: Priority.low,
            ongoing: true,
            autoCancel: false,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: false,
            presentBadge: false,
            presentSound: false,
          ),
        ),
        payload: 'focus|$taskTitle',
      );
    } catch (_) {}
  }

  Future<void> cancelOngoingFocus() async {
    if (kIsWeb) return;
    await _plugin.cancel(id: 998);
  }

  static const _sessionSchedule = [
    _S('morning', 'Morning', '5:00am', 'Morning habits time.'),
    _S('afternoon', 'Afternoon', '11:00am', 'Afternoon build session.'),
    _S('night', 'Night', '5:00pm', 'Night routine.'),
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
