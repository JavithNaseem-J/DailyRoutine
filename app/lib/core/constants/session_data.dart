import '../models/session.dart';
import '../theme/app_colors.dart';

// SESSION DATA — Empty task canvas!

abstract final class SessionData {
  /// All defined sessions (used for stats lookups, etc.)
  static List<Session> get allSessions => [
    _morning,
    _afternoon,
    _night,
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

  static Session? getById(String id) {
    // Migration: legacy 'weekend' / 'saturday' / 'sunday' / 'key_tasks' tasks map to morning
    if (id == 'weekend' || id == 'saturday' || id == 'sunday' || id == 'key_tasks') {
      return _morning;
    }
    try {
      return allSessions.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Returns the sessions active on the given [date].
  ///   - All days → Morning + Afternoon + Night
  static List<Session> sessionsForDate(DateTime date) {
    return [_morning, _afternoon, _night];
  }

  /// Convenience getter for today.
  static List<Session> get sessionsForToday => sessionsForDate(DateTime.now());
}
