/// QuickTask — ad-hoc task added from the Home tab quick-add section.
/// Max 5 per day. Auto-archived at midnight.
class QuickTask {
  QuickTask({
    required this.id,
    required this.date,
    required this.title,
    this.time,
    this.done = false,
    this.archived = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String date;
  String title;
  String? time;
  bool done;
  bool archived;
  final DateTime createdAt;

  QuickTask copyWith({
    String? title,
    String? time,
    bool? done,
    bool? archived,
  }) => QuickTask(
    id: id,
    date: date,
    title: title ?? this.title,
    time: time ?? this.time,
    done: done ?? this.done,
    archived: archived ?? this.archived,
    createdAt: createdAt,
  );

  factory QuickTask.fromJson(Map<String, dynamic> json) => QuickTask(
    id: json['id'] as String,
    date: json['date'] as String,
    title: json['title'] as String,
    time: json['time'] as String?,
    done: json['done'] as bool? ?? false,
    archived: json['archived'] as bool? ?? false,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date,
    'title': title,
    if (time != null) 'time': time,
    'done': done,
    'archived': archived,
    'created_at': createdAt.toIso8601String(),
  };
}
