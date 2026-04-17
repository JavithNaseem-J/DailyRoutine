/// DailyState — stores task/bonus completion and mood for one date.
///
/// Stored in Hive (key = date string "YYYY-MM-DD") and synced to Supabase.
class DailyState {
  DailyState({
    required this.date,
    Map<String, bool>? taskStates,
    Map<String, bool>? bonusStates,
    this.mood,
  })  : taskStates = taskStates ?? {},
        bonusStates = bonusStates ?? {};

  final String date;
  Map<String, bool> taskStates;   // taskId → done
  Map<String, bool> bonusStates;  // taskId → bonusDone
  String? mood;                   // "low" | "mid" | "high"

  DailyState copyWith({
    Map<String, bool>? taskStates,
    Map<String, bool>? bonusStates,
    String? mood,
  }) =>
      DailyState(
        date: date,
        taskStates: taskStates ?? Map.from(this.taskStates),
        bonusStates: bonusStates ?? Map.from(this.bonusStates),
        mood: mood ?? this.mood,
      );

  factory DailyState.empty(String date) =>
      DailyState(date: date, taskStates: {}, bonusStates: {});

  factory DailyState.fromJson(Map<String, dynamic> json) => DailyState(
        date: json['date'] as String,
        taskStates: (json['task_states'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, v as bool)),
        bonusStates: (json['bonus_states'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, v as bool)),
        mood: json['mood'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'date': date,
        'task_states': taskStates,
        'bonus_states': bonusStates,
        if (mood != null) 'mood': mood,
      };
}
