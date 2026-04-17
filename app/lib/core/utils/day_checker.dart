/// DayChecker — utility for day-specific logic.
abstract final class DayChecker {
  /// True on Fridays (weekday == 5).
  static bool isFriday([DateTime? date]) =>
      (date ?? DateTime.now()).weekday == DateTime.friday;

  /// True on Sundays (weekday == 7).
  static bool isSunday([DateTime? date]) =>
      (date ?? DateTime.now()).weekday == DateTime.sunday;

  /// True on Saturdays (weekday == 6).
  static bool isSaturday([DateTime? date]) =>
      (date ?? DateTime.now()).weekday == DateTime.saturday;
}
