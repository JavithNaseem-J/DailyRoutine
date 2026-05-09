/// DateService — handles date keys, midnight detection, and day formatting.
///
/// Date keys: "YYYY-MM-DD" strings used as Hive box keys and Supabase dates.
class DateService {
  static final DateService _instance = DateService._();
  factory DateService() => _instance;
  DateService._();

  /// Returns today's date key e.g. "2026-04-12"
  String todayKey() => keyFor(DateTime.now());

  /// Returns a date key for any [date]
  String keyFor(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Returns yesterday's date key
  String yesterdayKey() =>
      keyFor(DateTime.now().subtract(const Duration(days: 1)));

  /// True if the stored date key differs from today → day has changed.
  bool hasNewDayStarted(String storedKey) => storedKey != todayKey();

  /// Abbreviated weekday labels for the week strip (Sun–Sat).
  /// Returns list of 7 records: {day, dayIndex, isToday}.
  List<({String abbr, int dayIndex, bool isToday, DateTime date})>
  buildWeekStrip() {
    final now = DateTime.now();
    final todayWeekday = now.weekday; // 1=Mon…7=Sun
    final todayIndex = todayWeekday == 7 ? 0 : todayWeekday;

    // Build Sun → Sat strip
    final labels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return List.generate(7, (i) {
      final diff = i - todayIndex;
      final d = now.add(Duration(days: diff));
      return (abbr: labels[i], dayIndex: i, isToday: diff == 0, date: d);
    });
  }

  /// Returns today's day number (1–31) for the week strip date display.
  /// Aligns Sun=index 0 within the current week.
  List<({int dateNum, String abbr, bool isToday, DateTime date})>
  buildWeekStripWithDates() {
    final now = DateTime.now();
    final labels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return List.generate(30, (i) {
      final d = now.add(Duration(days: i));
      final dayIndex = d.weekday == 7 ? 0 : d.weekday;
      return (dateNum: d.day, abbr: labels[dayIndex], isToday: i == 0, date: d);
    });
  }
}

/// Singleton
final dateService = DateService();
