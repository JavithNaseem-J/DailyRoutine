import 'package:flutter/material.dart';
import '../models/session.dart';
import '../theme/app_colors.dart';

// SESSION DATA — Empty task canvas!

abstract final class SessionData {
  /// All defined sessions (used for stats lookups, etc.)
  static List<Session> get allSessions => [
    _morning,
    _afternoon,
    _night,
    _saturday,
    _sunday,
    _keyTasks,
  ];

  static final _morning = Session(
    id: 'morning',
    name: 'Morning',
    timeRange: '05:00 - 11:00',
    accentColor: AppColors.morning,
    tasks: [],
  );

  static final _afternoon = Session(
    id: 'afternoon',
    name: 'Afternoon',
    timeRange: '11:00 - 17:00',
    accentColor: AppColors.midday,
    tasks: [],
  );

  static final _night = Session(
    id: 'night',
    name: 'Night',
    timeRange: '17:00 - 23:00',
    accentColor: AppColors.evening,
    tasks: [],
  );

  static final _saturday = Session(
    id: 'saturday',
    name: 'Saturday',
    timeRange: 'All Day',
    accentColor: AppColors.midMorning,
    tasks: [],
    isWeekendOnly: true,
  );

  static final _sunday = Session(
    id: 'sunday',
    name: 'Sunday',
    timeRange: 'All Day',
    accentColor: AppColors.midMorning,
    tasks: [],
    isWeekendOnly: true,
  );

  static final _keyTasks = Session(
    id: 'key_tasks',
    name: 'Must Do',
    timeRange: 'All Day',
    accentColor: const Color(0xFFF59E0B),
    tasks: [],
  );

  static Session? getById(String id) {
    // Migration: legacy 'weekend' tasks map to saturday
    if (id == 'weekend') return _saturday;
    try {
      return allSessions.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Returns the sessions active on the given [date].
  ///   - Mon–Fri → Morning + Afternoon + Night + Key Tasks
  ///   - Saturday → Saturday + Key Tasks
  ///   - Sunday → Sunday + Key Tasks
  static List<Session> sessionsForDate(DateTime date) {
    // All days use Morning / Afternoon / Night / Must Do.
    // Weekend-only sessions (saturday, sunday) are kept in allSessions
    // for backward-compat with legacy data but no longer shown in the UI.
    return [_morning, _afternoon, _night, _keyTasks];
  }

  /// Convenience getter for today.
  static List<Session> get sessionsForToday => sessionsForDate(DateTime.now());
}
