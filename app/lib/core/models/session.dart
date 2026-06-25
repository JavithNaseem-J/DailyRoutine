import 'package:flutter/material.dart';

// Data models for the session/task system

/// The four visual states of a session pill.
enum SessionPillState {
  empty, // 0 tasks done
  started, // 1+ done, under 50 %
  halfway, // 50 %+ done, not complete
  complete, // all done
}

enum StateOfMind { flow, quick, easy, personal }

// Task
class Task {
  const Task({
    required this.id,
    required this.sessionId,
    required this.title,
    required this.time,
    required this.durationMinutes,
    required this.tip,
    this.isBreak = false,
    this.hasSessionTimer = false,
    this.iconName = 'star',
    this.weekdays = const [], // empty = all days (Mon=1 … Sun=7, ISO 8601)
    this.stateOfMind,
    this.isUrgent = false,
    this.priority,
    this.createdAt,
  });

  final String id;
  final String sessionId;
  final String title;
  final String time; // "7:00am"
  final int durationMinutes; // used for duration bar width
  final String tip;
  final bool isBreak;
  final bool hasSessionTimer;
  final String iconName;
  /// The weekdays this task is active on (1=Mon … 7=Sun, ISO 8601).
  /// Empty list = active every day.
  final List<int> weekdays;

  final StateOfMind? stateOfMind;
  final bool isUrgent;
  final String? priority;
  final DateTime? createdAt;

  bool get isKeyTask => tip.startsWith('key_task:true');
  String get cleanTip {
    if (tip.startsWith('key_task:true|')) {
      return tip.substring('key_task:true|'.length);
    }
    if (tip.startsWith('key_task:false|')) {
      return tip.substring('key_task:false|'.length);
    }
    return tip;
  }

  /// Returns true if this task should be shown on [date]
  bool isActiveOn(DateTime date) {
    if (weekdays.isEmpty) return true;
    return weekdays.contains(date.weekday); // weekday: Mon=1 … Sun=7
  }

  Task copyWith({
    String? id,
    String? sessionId,
    String? title,
    String? time,
    int? durationMinutes,
    String? tip,
    bool? isBreak,
    bool? hasSessionTimer,
    String? iconName,
    List<int>? weekdays,
    StateOfMind? stateOfMind,
    bool? isUrgent,
    String? priority,
    DateTime? createdAt,
  }) {
    return Task(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      title: title ?? this.title,
      time: time ?? this.time,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      tip: tip ?? this.tip,
      isBreak: isBreak ?? this.isBreak,
      hasSessionTimer: hasSessionTimer ?? this.hasSessionTimer,
      iconName: iconName ?? this.iconName,
      weekdays: weekdays ?? this.weekdays,
      stateOfMind: stateOfMind ?? this.stateOfMind,
      isUrgent: isUrgent ?? this.isUrgent,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    // Parse weekdays from stored comma-separated string e.g. "1,2,3"
    final weekdaysRaw = json['weekdays'] as String? ?? '';
    final parsedWeekdays = weekdaysRaw.isEmpty
        ? <int>[]
        : weekdaysRaw
            .split(',')
            .map((s) => int.tryParse(s.trim()))
            .whereType<int>()
            .toList();

    StateOfMind? som;
    if (json['stateOfMind'] != null) {
      som = StateOfMind.values.firstWhere(
        (e) => e.name == json['stateOfMind'],
        orElse: () => StateOfMind.flow,
      );
    } else if (json['state_of_mind'] != null) {
      som = StateOfMind.values.firstWhere(
        (e) => e.name == json['state_of_mind'],
        orElse: () => StateOfMind.flow,
      );
    }

    return Task(
      id: json['id'] as String? ?? '',
      sessionId: json['sessionId'] as String? ?? json['session_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      time: json['time'] as String? ?? '',
      durationMinutes: json['durationMinutes'] as int? ?? json['duration_minutes'] as int? ?? 15,
      tip: json['tip'] as String? ?? '',
      isBreak: json['isBreak'] as bool? ?? json['is_break'] as bool? ?? false,
      hasSessionTimer: json['hasSessionTimer'] as bool? ?? json['has_session_timer'] as bool? ?? false,
      iconName: json['iconName'] as String? ?? json['icon_name'] as String? ?? 'star',
      weekdays: parsedWeekdays,
      stateOfMind: som,
      isUrgent: json['isUrgent'] as bool? ?? json['is_urgent'] as bool? ?? false,
      priority: json['priority'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : (json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sessionId': sessionId,
      'title': title,
      'time': time,
      'durationMinutes': durationMinutes,
      'tip': tip,
      'isBreak': isBreak,
      'hasSessionTimer': hasSessionTimer,
      'iconName': iconName,
      'weekdays': weekdays.join(','), // stored as "1,2,3" — empty string = all days
      if (stateOfMind != null) 'stateOfMind': stateOfMind!.name,
      'isUrgent': isUrgent,
      if (priority != null) 'priority': priority,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    };
  }
}

// Session
class Session {
  const Session({
    required this.id,
    required this.name,
    required this.timeRange,
    required this.accentColor,
    required this.tasks,
    this.isWeekendOnly = false,
  });

  final String id;
  final String name;
  final String timeRange;
  final Color accentColor;
  final List<Task> tasks;
  /// True for Saturday/Sunday-only sessions (kept for backward-compat with legacy data)
  final bool isWeekendOnly;
}
