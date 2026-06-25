/// DailyState — stores task completion, mood, and focus for one date.
///
/// Stored in Hive (key = date string "YYYY-MM-DD") and synced to Supabase.
class DailyState {
  DailyState({
    required this.date,
    Map<String, bool>? taskStates,
    Map<String, String>? taskStatus,
    Map<String, bool>? bonusStates,
    this.mood,
    this.focusMinutes = 0,
    List<int>? focusSessions,
    Map<String, int>? projectMinutes,
    Map<String, bool>? prayerStates,
    this.jobApplicationsCount = 0,
  }) : taskStates = taskStates ?? {},
       taskStatus = taskStatus ?? {},
       bonusStates = bonusStates ?? {},
       focusSessions = focusSessions ?? [],
       projectMinutes = projectMinutes ?? {},
       prayerStates = prayerStates ?? {};

  final String date;
  Map<String, bool> taskStates; // taskId → done
  Map<String, String> taskStatus; // taskId → 'on_time' | 'late'
  Map<String, bool> bonusStates; // taskId → done
  String? mood; // "low" | "mid" | "high"
  int focusMinutes; // Total focus timer minutes logged today
  List<int> focusSessions; // Individual session durations (minutes)
  Map<String, int> projectMinutes; // tag/taskId → minutes
  Map<String, bool> prayerStates; // prayerName → done
  int jobApplicationsCount;

  DailyState copyWith({
    Map<String, bool>? taskStates,
    Map<String, String>? taskStatus,
    Map<String, bool>? bonusStates,
    String? mood,
    int? focusMinutes,
    List<int>? focusSessions,
    Map<String, int>? projectMinutes,
    Map<String, bool>? prayerStates,
    int? jobApplicationsCount,
  }) => DailyState(
    date: date,
    taskStates: taskStates ?? Map.from(this.taskStates),
    taskStatus: taskStatus ?? Map.from(this.taskStatus),
    bonusStates: bonusStates ?? Map.from(this.bonusStates),
    mood: mood ?? this.mood,
    focusMinutes: focusMinutes ?? this.focusMinutes,
    focusSessions: focusSessions ?? List.from(this.focusSessions),
    projectMinutes: projectMinutes ?? Map.from(this.projectMinutes),
    prayerStates: prayerStates ?? Map.from(this.prayerStates),
    jobApplicationsCount: jobApplicationsCount ?? this.jobApplicationsCount,
  );

  factory DailyState.empty(String date) =>
      DailyState(
        date: date,
        taskStates: {},
        taskStatus: {},
        bonusStates: {},
        focusSessions: [],
        projectMinutes: {},
        prayerStates: {},
        jobApplicationsCount: 0,
      );

  factory DailyState.fromJson(Map<String, dynamic> json) => DailyState(
    date: json['date'] as String,
    taskStates: (json['task_states'] as Map<String, dynamic>? ?? {}).map(
      (k, v) => MapEntry(k, v as bool),
    ),
    taskStatus: (json['task_status'] as Map<String, dynamic>? ?? {}).map(
      (k, v) => MapEntry(k, v as String),
    ),
    bonusStates: (json['bonus_states'] as Map<String, dynamic>? ?? {}).map(
      (k, v) => MapEntry(k, v as bool),
    ),
    mood: json['mood'] as String?,
    focusMinutes: json['focus_minutes'] as int? ?? 0,
    focusSessions: (json['focus_sessions'] as List<dynamic>? ?? []).map((e) => (e as num).toInt()).toList(),
    projectMinutes: (json['project_minutes'] as Map<String, dynamic>? ?? {}).map(
      (k, v) => MapEntry(k, (v as num).toInt()),
    ),
    prayerStates: (json['prayer_states'] as Map<String, dynamic>? ?? {}).map(
      (k, v) => MapEntry(k, v as bool),
    ),
    jobApplicationsCount: json['job_applications_count'] as int? ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'date': date,
    'task_states': taskStates,
    'task_status': taskStatus,
    'bonus_states': bonusStates,
    if (mood != null) 'mood': mood,
    'focus_minutes': focusMinutes,
    'focus_sessions': focusSessions,
    'project_minutes': projectMinutes,
    'prayer_states': prayerStates,
    'job_applications_count': jobApplicationsCount,
  };
}
