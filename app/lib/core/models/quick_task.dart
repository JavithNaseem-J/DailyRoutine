/// QuickTask â€” ad-hoc task added from the Home tab quick-add section.
/// Max 5 per day. Auto-archived at midnight.
class QuickTask {
  QuickTask({
    required this.id,
    required this.date,
    required this.title,
    this.time,
    this.done = false,
    this.archived = false, this.isUrgent = false, this.isImportant = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String date;
  String title;
  String? time;
  bool done;
  bool archived; bool isUrgent; bool isImportant;
  final DateTime createdAt;

  QuickTask copyWith({
    String? title,
    String? time,
    bool? done,
    bool? archived, bool? isUrgent, bool? isImportant,
  }) => QuickTask(
    id: id,
    date: date,
    title: title ?? this.title,
    time: time ?? this.time,
    done: done ?? this.done,
    archived: archived ?? this.archived, isUrgent: isUrgent ?? this.isUrgent, isImportant: isImportant ?? this.isImportant,
    createdAt: createdAt,
  );

  factory QuickTask.fromJson(Map<String, dynamic> json) => QuickTask(
    id: json['id'] as String,
    date: json['date'] as String,
    title: json['title'] as String,
    time: json['time'] as String?,
    done: json['done'] as bool? ?? false,
    archived: json['archived'] as bool? ?? false, isUrgent: json['is_urgent'] as bool? ?? false, isImportant: json['is_important'] as bool? ?? false,
    // BUG-017 fix: safely handle missing/malformed created_at from older data
    createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date,
    'title': title,
    if (time != null) 'time': time,
    'done': done,
    'archived': archived, 'is_urgent': isUrgent, 'is_important': isImportant,
    'created_at': createdAt.toIso8601String(),
  };
}

