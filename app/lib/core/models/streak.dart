/// Streak — tracks daily completion streak and the week strip (7 days).
class Streak {
  Streak({
    required this.deviceId,
    Map<int, bool>? weekStrip,
    this.currentStreak = 0,
    this.bestStreak = 0,
  }) : weekStrip = weekStrip ?? {};

  final String deviceId;
  Map<int, bool> weekStrip;   // dayIndex 0=Sun … 6=Sat → complete
  int currentStreak;
  int bestStreak;

  Streak copyWith({
    Map<int, bool>? weekStrip,
    int? currentStreak,
    int? bestStreak,
  }) =>
      Streak(
        deviceId: deviceId,
        weekStrip: weekStrip ?? Map.from(this.weekStrip),
        currentStreak: currentStreak ?? this.currentStreak,
        bestStreak: bestStreak ?? this.bestStreak,
      );

  factory Streak.empty(String deviceId) =>
      Streak(deviceId: deviceId);

  factory Streak.fromJson(String deviceId, Map<String, dynamic> json) =>
      Streak(
        deviceId: deviceId,
        weekStrip: (json['week_strip'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(int.parse(k), v as bool)),
        currentStreak: json['current_streak'] as int? ?? 0,
        bestStreak: json['best_streak'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'device_id': deviceId,
        'week_strip': weekStrip.map((k, v) => MapEntry(k.toString(), v)),
        'current_streak': currentStreak,
        'best_streak': bestStreak,
      };
}
