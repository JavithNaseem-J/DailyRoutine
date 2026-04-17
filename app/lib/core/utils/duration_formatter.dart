/// DurationFormatter — converts minutes/Duration to human-readable strings.
abstract final class DurationFormatter {
  /// 30 → "30 min"  |  90 → "1h 30min"
  static String fromMinutes(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}min';
  }

  /// Duration → "1h 20min" (used in prayer countdown)
  static String fromDuration(Duration d) {
    final totalMinutes = d.inMinutes;
    if (totalMinutes <= 0) return '0 min';
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    if (h == 0) return '${m}min';
    if (m == 0) return '${h}h';
    return '${h}h ${m}min';
  }

  /// Duration → "MM:SS" (used in session countdown timer)
  static String toMMSS(Duration d) {
    final total = d.inSeconds.clamp(0, 99 * 60 + 59); // clamp to safety
    final m = total ~/ 60;
    final s = total % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
