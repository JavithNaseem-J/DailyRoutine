import '../models/session.dart';
import '../theme/app_colors.dart';

// SESSION DATA — Empty task canvas!

abstract final class SessionData {
  /// All defined sessions (used for stats lookups, etc.)
  static List<Session> get allSessions => [
    _morning,
    _afternoon,
    _night,
    _saturday,
    _sunday,
  ];

  static final _morning = Session(
    id: 'morning',
    name: 'Morning',
    timeRange: '05:00 - 11:00',
    accentColor: AppColors.morning,
    tasks: [],
  );

  static final _afternoon = Session(
    id: 'afternoon',
    name: 'Afternoon',
    timeRange: '11:00 - 17:00',
    accentColor: AppColors.midday,
    tasks: [],
  );

  static final _night = Session(
    id: 'night',
    name: 'Night',
    timeRange: '17:00 - 23:00',
    accentColor: AppColors.evening,
    tasks: [],
  );

  static final _saturday = Session(
    id: 'saturday',
    name: 'Saturday',
    timeRange: 'All Day',
    accentColor: AppColors.midMorning,
    tasks: [],
    isWeekendOnly: true,
  );

  static final _sunday = Session(
    id: 'sunday',
    name: 'Sunday',
    timeRange: 'All Day',
    accentColor: AppColors.midMorning,
    tasks: [],
    isWeekendOnly: true,
  );

  static Session? getById(String id) {
    // Migration: legacy 'weekend' tasks map to saturday
    if (id == 'weekend') return _saturday;
    try {
      return allSessions.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Returns the sessions active on the given [date].
  ///   - Mon–Fri → Morning + Afternoon + Night
  ///   - Saturday → Saturday
  ///   - Sunday → Sunday
  static List<Session> sessionsForDate(DateTime date) {
    switch (date.weekday) {
      case DateTime.saturday:
        return [_saturday];
      case DateTime.sunday:
        return [_sunday];
      default:
        return [_morning, _afternoon, _night];
    }
  }

  /// Convenience getter for today.
  static List<Session> get sessionsForToday => sessionsForDate(DateTime.now());
}
