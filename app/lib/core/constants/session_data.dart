import '../models/session.dart';
import '../theme/app_colors.dart';

// SESSION DATA — Empty task canvas!

abstract final class SessionData {
  static List<Session> get allSessions => [
    _morning,
    _afternoon,
    _evening,
    _night,
    _weekend,
  ];

  static final _morning = Session(
    id: 'morning',
    name: 'Morning',
    timeRange: '05:00 - 12:00',
    accentColor: AppColors.morning,
    tasks: [],
  );

  static final _afternoon = Session(
    id: 'afternoon',
    name: 'Afternoon',
    timeRange: '12:00 - 16:00',
    accentColor: AppColors.midday,
    tasks: [],
  );

  static final _evening = Session(
    id: 'evening',
    name: 'Evening',
    timeRange: '16:00 - 19:00',
    accentColor: AppColors.sunset,
    tasks: [],
  );

  static final _night = Session(
    id: 'night',
    name: 'Night',
    timeRange: '19:00 - 22:30',
    accentColor: AppColors.evening,
    tasks: [],
  );

  static final _weekend = Session(
    id: 'weekend',
    name: 'Weekend',
    timeRange: 'All Day',
    accentColor: AppColors.midMorning,
    tasks: [],
  );

  static Session? getById(String id) {
    try {
      return allSessions.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  static List<Session> sessionsForToday({bool isFriday = false}) {
    return allSessions.where((s) {
      if (s.isFridayOnly && !isFriday) return false;
      return true;
    }).toList();
  }

}
