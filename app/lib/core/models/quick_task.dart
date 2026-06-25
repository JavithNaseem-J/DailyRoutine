import 'session.dart' show StateOfMind;

/// QuickTask — ad-hoc task added from the Home tab quick-add section.
/// Persistent until manually deleted by the user.
class QuickTask {
  QuickTask({
    required this.id,
    required this.date,
    required this.title,
    this.time,
    this.done = false,
    this.archived = false,
    this.isUrgent = false,
    this.isImportant = false,
    this.priority,
    this.deadline,
    this.delegatee,
    this.stateOfMind,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String date;
  String title;
  String? time;
  bool done;
  bool archived;
  bool isUrgent;
  bool isImportant;

  /// Priority flag for "Do it" quadrant: 'P1', 'P2', 'P3', or null.
  String? priority;

  /// Deadline date for "Schedule it" quadrant (ISO date string, e.g. '2025-05-25').
  String? deadline;

  /// Delegatee name for "Delegate it" quadrant.
  String? delegatee;

  /// State of Mind / Cognitive load indicator.
  StateOfMind? stateOfMind;

  final DateTime createdAt;

  QuickTask copyWith({
    String? title,
    String? time,
    bool? done,
    bool? archived,
    bool? isUrgent,
    bool? isImportant,
    Object? priority = _sentinel,
    Object? deadline = _sentinel,
    Object? delegatee = _sentinel,
    Object? stateOfMind = _sentinel,
  }) => QuickTask(
    id: id,
    date: date,
    title: title ?? this.title,
    time: time ?? this.time,
    done: done ?? this.done,
    archived: archived ?? this.archived,
    isUrgent: isUrgent ?? this.isUrgent,
    isImportant: isImportant ?? this.isImportant,
    priority: priority == _sentinel ? this.priority : priority as String?,
    deadline: deadline == _sentinel ? this.deadline : deadline as String?,
    delegatee: delegatee == _sentinel ? this.delegatee : delegatee as String?,
    stateOfMind: stateOfMind == _sentinel ? this.stateOfMind : stateOfMind as StateOfMind?,
    createdAt: createdAt,
  );

  factory QuickTask.fromJson(Map<String, dynamic> json) {
    StateOfMind? som;
    final somJson = json['state_of_mind'] ?? json['stateOfMind'];
    if (somJson != null) {
      som = StateOfMind.values.firstWhere(
        (e) => e.name == somJson,
        orElse: () => StateOfMind.flow,
      );
    }
    return QuickTask(
      id: json['id'] as String,
      date: json['date'] as String,
      title: json['title'] as String,
      time: json['time'] as String?,
      done: json['done'] as bool? ?? false,
      archived: json['archived'] as bool? ?? false,
      isUrgent: json['is_urgent'] as bool? ?? false,
      isImportant: json['is_important'] as bool? ?? false,
      priority: json['priority'] as String?,
      deadline: json['deadline'] as String?,
      delegatee: json['delegatee'] as String?,
      stateOfMind: som,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date,
    'title': title,
    if (time != null) 'time': time,
    'done': done,
    'archived': archived,
    'is_urgent': isUrgent,
    'is_important': isImportant,
    if (priority != null) 'priority': priority,
    if (deadline != null) 'deadline': deadline,
    if (delegatee != null) 'delegatee': delegatee,
    if (stateOfMind != null) 'state_of_mind': stateOfMind!.name,
    'created_at': createdAt.toIso8601String(),
  };
}

// Sentinel object for nullable copyWith fields
const Object _sentinel = Object();
