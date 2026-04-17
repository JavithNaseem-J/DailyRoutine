import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data models for the session/task system
// ─────────────────────────────────────────────────────────────────────────────

/// Which habit ring a task contributes to.
enum RingType { worship, build, body, none }

/// The four visual states of a session pill.
enum SessionPillState {
  empty,    // 0 tasks done
  started,  // 1+ done, under 50 %
  halfway,  // 50 %+ done, not complete
  complete, // all done
}

// ─────────────────────────────────────────────────────────────────────────────
// Task
// ─────────────────────────────────────────────────────────────────────────────
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
    this.isSundayOnly = false,
    this.isFridaySpecial = false,
  });

  final String id;
  final String sessionId;
  final String title;
  final String time;            // "7:00am"
  final int durationMinutes;    // used for duration bar width
  final String tip;
  final String? bonus;
  final String? subtitle;       // injected from Today's Focus
  final RingType ring;
  final bool isBreak;
  final bool hasSessionTimer;   // build sessions 1, 2, 3 only
  final bool isFridayOnly;
  final bool isSundayOnly;
  final bool isFridaySpecial;   // Dhuhr → Jumu'ah on Fridays
}

// ─────────────────────────────────────────────────────────────────────────────
// Session
// ─────────────────────────────────────────────────────────────────────────────
class Session {
  const Session({
    required this.id,
    required this.name,
    required this.timeRange,
    required this.accentColor,
    required this.tasks,
    this.isFridayOnly = false,
    this.isSundayOnly = false,
  });

  final String id;
  final String name;
  final String timeRange;
  final Color accentColor;
  final List<Task> tasks;
  final bool isFridayOnly;
  final bool isSundayOnly;
}
