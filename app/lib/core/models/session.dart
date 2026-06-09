import 'package:flutter/material.dart';

// Data models for the session/task system

/// Which habit ring a task contributes to.
enum RingType { worship, build, body, none }

/// The four visual states of a session pill.
enum SessionPillState {
  empty, // 0 tasks done
  started, // 1+ done, under 50 %
  halfway, // 50 %+ done, not complete
  complete, // all done
}

// Task
class Task {
  const Task({
    required this.id,
    required this.sessionId,
    required this.title,
    required this.time,
    required this.durationMinutes,
    required this.tip,
    this.bonus,
    this.subtitle,
    this.ring = RingType.none,
    this.isBreak = false,
    this.hasSessionTimer = false,
    this.isFridayOnly = false,
    this.isFridaySpecial = false,
    this.iconName = 'star',
    this.weekdays = const [], // empty = all days (Mon=1 … Sun=7, ISO 8601)
  });

  final String id;
  final String sessionId;
  final String title;
  final String time; // "7:00am"
  final int durationMinutes; // used for duration bar width
  final String tip;
  final String? bonus;
  final String? subtitle; // injected from Today's Focus
  final RingType ring;
  final bool isBreak;
  final bool hasSessionTimer; // build sessions 1, 2, 3 only
  final bool isFridayOnly;
  final bool isFridaySpecial; // Dhuhr → Jumu'ah on Fridays
  final String iconName;
  /// The weekdays this task is active on (1=Mon … 7=Sun, ISO 8601).
  /// Empty list = active every day.
  final List<int> weekdays;

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
    String? bonus,
    String? subtitle,
    RingType? ring,
    bool? isBreak,
    bool? hasSessionTimer,
    bool? isFridayOnly,
    bool? isFridaySpecial,
    String? iconName,
    List<int>? weekdays,
  }) {
    return Task(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      title: title ?? this.title,
      time: time ?? this.time,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      tip: tip ?? this.tip,
      bonus: bonus ?? this.bonus,
      subtitle: subtitle ?? this.subtitle,
      ring: ring ?? this.ring,
      isBreak: isBreak ?? this.isBreak,
      hasSessionTimer: hasSessionTimer ?? this.hasSessionTimer,
      isFridayOnly: isFridayOnly ?? this.isFridayOnly,
      isFridaySpecial: isFridaySpecial ?? this.isFridaySpecial,
      iconName: iconName ?? this.iconName,
      weekdays: weekdays ?? this.weekdays,
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

    return Task(
      id: json['id'] as String? ?? '',
      sessionId: json['sessionId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      time: json['time'] as String? ?? '',
      durationMinutes: json['durationMinutes'] as int? ?? 15,
      tip: json['tip'] as String? ?? '',
      bonus: json['bonus'] as String?,
      subtitle: json['subtitle'] as String?,
      ring: RingType.values.firstWhere(
        (e) => e.name == (json['ring'] as String?),
        orElse: () => RingType.none,
      ),
      isBreak: json['isBreak'] as bool? ?? false,
      hasSessionTimer: json['hasSessionTimer'] as bool? ?? false,
      isFridayOnly: json['isFridayOnly'] as bool? ?? false,
      isFridaySpecial: json['isFridaySpecial'] as bool? ?? false,
      iconName: json['iconName'] as String? ?? 'star',
      weekdays: parsedWeekdays,
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
      'bonus': bonus,
      'subtitle': subtitle,
      'ring': ring.name,
      'isBreak': isBreak,
      'hasSessionTimer': hasSessionTimer,
      'isFridayOnly': isFridayOnly,
      'isFridaySpecial': isFridaySpecial,
      'iconName': iconName,
      'weekdays': weekdays.join(','), // stored as "1,2,3" — empty string = all days
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
    this.isFridayOnly = false,
    this.isWeekendOnly = false,
  });

  final String id;
  final String name;
  final String timeRange;
  final Color accentColor;
  final List<Task> tasks;
  final bool isFridayOnly;
  /// True for Saturday/Sunday-only sessions
  final bool isWeekendOnly;
}
