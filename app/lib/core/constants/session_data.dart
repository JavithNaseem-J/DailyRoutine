import '../models/session.dart';
import '../theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SESSION DATA — Empty task canvas!
// ─────────────────────────────────────────────────────────────────────────────

abstract final class SessionData {
  static List<Session> get allSessions => [
    _morning,
    _afternoon,
    _evening,
    _night,
    _sundayPlanning,
  ];

  static final _morning = Session(
    id: 'morning',
    name: 'Morning',
    timeRange: '5:30 AM – 12:00 PM',
    accentColor: AppColors.morning,
    tasks: [],
  );

  static final _afternoon = Session(
    id: 'afternoon',
    name: 'Afternoon',
    timeRange: '12:00 PM – 4:00 PM',
    accentColor: AppColors.midday,
    tasks: [],
  );

  static final _evening = Session(
    id: 'evening',
    name: 'Evening',
    timeRange: '4:00 PM – 7:00 PM',
    accentColor: AppColors.sunset,
    tasks: [],
  );

  static final _night = Session(
    id: 'night',
    name: 'Night',
    timeRange: '7:00 PM – 10:30 PM',
    accentColor: AppColors.evening,
    tasks: [],
  );

  static final _sundayPlanning = Session(
    id: 'sunday_planning',
    name: 'Sunday Planning',
    timeRange: 'All Day',
    accentColor: AppColors.primary,
    isSundayOnly: true,
    tasks: [],
  );

  // ── Helpers ──────────────────────────────────────────────────────────────

  static Session? getById(String id) {
    try {
      return allSessions.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  static List<Session> sessionsForToday({
    bool isFriday = false,
    bool isSunday = false,
  }) {
    return allSessions.where((s) {
      if (s.isFridayOnly && !isFriday) return false;
      if (s.isSundayOnly && !isSunday) return false;
      return true;
    }).toList();
  }

  static List<String> get allTaskIds => [];

  static List<String> taskIdsForToday({
    bool isFriday = false,
    bool isSunday = false,
  }) => [];
}
