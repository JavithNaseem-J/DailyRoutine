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
