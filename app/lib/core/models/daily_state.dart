/// DailyState — stores task/bonus completion and mood for one date.
///
/// Stored in Hive (key = date string "YYYY-MM-DD") and synced to Supabase.
class DailyState {
  DailyState({
    required this.date,
    Map<String, bool>? taskStates,
    Map<String, bool>? bonusStates,
    this.mood,
    this.focusMinutes = 0,
    Map<String, int>? projectMinutes,
    Map<String, bool>? prayerStates,
  }) : taskStates = taskStates ?? {},
       bonusStates = bonusStates ?? {},
       projectMinutes = projectMinutes ?? {},
       prayerStates = prayerStates ?? {};

  final String date;
  Map<String, bool> taskStates; // taskId → done
  Map<String, bool> bonusStates; // taskId → bonusDone
  String? mood; // "low" | "mid" | "high"
  int focusMinutes; // Total focus timer minutes logged today
  Map<String, int> projectMinutes; // tagId → minutes
  Map<String, bool> prayerStates; // prayerName → done

  DailyState copyWith({
    Map<String, bool>? taskStates,
    Map<String, bool>? bonusStates,
    String? mood,
    int? focusMinutes,
    Map<String, int>? projectMinutes,
    Map<String, bool>? prayerStates,
  }) => DailyState(
    date: date,
    taskStates: taskStates ?? Map.from(this.taskStates),
    bonusStates: bonusStates ?? Map.from(this.bonusStates),
    mood: mood ?? this.mood,
    focusMinutes: focusMinutes ?? this.focusMinutes,
    projectMinutes: projectMinutes ?? Map.from(this.projectMinutes),
    prayerStates: prayerStates ?? Map.from(this.prayerStates),
  );

  factory DailyState.empty(String date) =>
      DailyState(date: date, taskStates: {}, bonusStates: {}, prayerStates: {});

  factory DailyState.fromJson(Map<String, dynamic> json) => DailyState(
    date: json['date'] as String,
    taskStates: (json['task_states'] as Map<String, dynamic>? ?? {}).map(
      (k, v) => MapEntry(k, v as bool),
    ),
    bonusStates: (json['bonus_states'] as Map<String, dynamic>? ?? {}).map(
      (k, v) => MapEntry(k, v as bool),
    ),
    mood: json['mood'] as String?,
    focusMinutes: json['focus_minutes'] as int? ?? 0,
    projectMinutes: (json['project_minutes'] as Map<String, dynamic>? ?? {}).map(
      (k, v) => MapEntry(k, (v as num).toInt()),
    ),
    prayerStates: (json['prayer_states'] as Map<String, dynamic>? ?? {}).map(
      (k, v) => MapEntry(k, v as bool),
    ),
  );

  Map<String, dynamic> toJson() => {
    'date': date,
    'task_states': taskStates,
    'bonus_states': bonusStates,
    if (mood != null) 'mood': mood,
    'focus_minutes': focusMinutes,
    'project_minutes': projectMinutes,
    'prayer_states': prayerStates,
  };
}
