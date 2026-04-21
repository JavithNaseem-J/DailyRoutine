import '../models/session.dart';
import '../theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SESSION DATA — Empty task canvas!
// ─────────────────────────────────────────────────────────────────────────────

abstract final class SessionData {
  static List<Session> get allSessions => [
    _fajr,
    _earlyMorning,
    _lateMorning,
    _dhuhr,
    _asr,
    _maghrib,
    _isha,
    _fridayReview,
    _sundayPlanning,
  ];

  static final _fajr = Session(
    id: 'fajr',
    name: 'Dawn',
    timeRange: '5:00 – 7:00am',
    accentColor: AppColors.worship,
    tasks: [],
  );

  static final _earlyMorning = Session(
    id: 'early_morning',
    name: 'Early Morning',
    timeRange: '7:00 – 9:30am',
    accentColor: AppColors.build,
    tasks: [],
  );

  static final _lateMorning = Session(
    id: 'late_morning',
    name: 'Late Morning',
    timeRange: '9:30am – 12:15pm',
    accentColor: AppColors.morning,
    tasks: [],
  );

  static final _dhuhr = Session(
    id: 'dhuhr',
    name: 'Noon',
    timeRange: '12:15 – 3:45pm',
    accentColor: AppColors.midday,
    tasks: [],
  );

  static final _asr = Session(
    id: 'asr',
    name: 'Afternoon',
    timeRange: '3:45 – 6:15pm',
    accentColor: AppColors.afternoon,
    tasks: [],
  );

  static final _maghrib = Session(
    id: 'maghrib',
    name: 'Evening',
    timeRange: '6:15 – 7:45pm',
    accentColor: AppColors.sunset,
    tasks: [],
  );

  static final _isha = Session(
    id: 'isha',
    name: 'Night',
    timeRange: '7:45 – 10:30pm',
    accentColor: AppColors.evening,
    tasks: [],
  );

  static final _fridayReview = Session(
    id: 'friday_review',
    name: 'Friday Review',
    timeRange: '2:00 – 3:30pm',
    accentColor: AppColors.worship,
    isFridayOnly: true,
    tasks: [],
  );

  static final _sundayPlanning = Session(
    id: 'sunday_planning',
    name: 'Sunday Planning',
    timeRange: '9:00 – 10:30am',
    accentColor: AppColors.worship,
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
