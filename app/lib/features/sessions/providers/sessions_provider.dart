import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/session_data.dart';
import '../../../core/models/daily_state.dart';
import '../../../core/models/session.dart';
import '../../../core/models/streak.dart';
import '../../../core/services/date_service.dart';
import '../../../core/services/hive_service.dart';
import '../../../core/services/streak_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/day_checker.dart';
import '../../../main.dart' show deviceId;

// ─────────────────────────────────────────────────────────────────────────────
// SessionsState
// ─────────────────────────────────────────────────────────────────────────────

class SessionsState {
  const SessionsState({
    required this.dailyState,
    required this.sessions,
    required this.activeSessionId,
  });

  final DailyState dailyState;
  final List<Session> sessions;
  final String? activeSessionId;

  Map<String, bool> get taskStates => dailyState.taskStates;
  Map<String, bool> get bonusStates => dailyState.bonusStates;

  bool isTaskDone(String taskId) => dailyState.taskStates[taskId] ?? false;
  bool isBonusDone(String taskId) => dailyState.bonusStates[taskId] ?? false;

  SessionPillState pillState(String sessionId) {
    final session = sessions.firstWhere(
      (s) => s.id == sessionId,
      orElse: () => sessions.first,
    );
    final taskIds = session.tasks.map((t) => t.id).toList();
    final doneCount = taskIds.where((id) => taskStates[id] == true).length;
    if (doneCount == 0) return SessionPillState.empty;
    if (doneCount == taskIds.length) return SessionPillState.complete;
    if (doneCount / taskIds.length >= 0.5) return SessionPillState.halfway;
    return SessionPillState.started;
  }

  bool isSessionComplete(String sessionId) =>
      pillState(sessionId) == SessionPillState.complete;

  int get completionPct {
    final allIds = SessionData.taskIdsForToday(
      isFriday: DayChecker.isFriday(),
      isSunday: DayChecker.isSunday(),
    );
    if (allIds.isEmpty) return 0;
    final doneCount = allIds.where((id) => taskStates[id] == true).length;
    return ((doneCount / allIds.length) * 100).round();
  }

  Session? get activeSession => sessions.firstWhere(
        (s) => s.id == (activeSessionId ?? ''),
        orElse: () => sessions.isNotEmpty ? sessions.first : sessions.first,
      );

  SessionsState copyWith({DailyState? dailyState}) => SessionsState(
        dailyState: dailyState ?? this.dailyState,
        sessions: sessions,
        activeSessionId: activeSessionId,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// SessionsNotifier  (Riverpod 3.x — state is AsyncValue<SessionsState>)
// ─────────────────────────────────────────────────────────────────────────────

class SessionsNotifier extends AsyncNotifier<SessionsState> {
  String get _todayKey => dateService.todayKey();

  @override
  Future<SessionsState> build() async {
    final sessions = SessionData.sessionsForToday(
      isFriday: DayChecker.isFriday(),
      isSunday: DayChecker.isSunday(),
    );

    // 1. Load from Hive instantly
    final daily = hiveService.readDailyState(_todayKey);

    // 2. Refresh from Supabase in the background
    _refreshFromSupabase(daily, sessions);

    return SessionsState(
      dailyState: daily,
      sessions: sessions,
      activeSessionId: _findActiveSessionId(sessions),
    );
  }

  Future<void> _refreshFromSupabase(
      DailyState localState, List<Session> sessions) async {
    final remote = await supabaseService.fetchDailyState(_todayKey, deviceId);
    if (remote == null) return;

    final merged = DailyState(
      date: _todayKey,
      taskStates: {...localState.taskStates, ...remote.taskStates},
      bonusStates: {...localState.bonusStates, ...remote.bonusStates},
      mood: remote.mood ?? localState.mood,
    );

    await hiveService.writeDailyState(merged);

    // Riverpod 3: state.value
    final current = state.value;
    if (current != null) {
      state = AsyncData(current.copyWith(dailyState: merged));
    }
  }

  String? _findActiveSessionId(List<Session> sessions) {
    final now = TimeOfDay.now();
    final nowMin = now.hour * 60 + now.minute;
    for (final s in sessions) {
      final range = s.timeRange.split('–').map((p) => p.trim()).toList();
      if (range.length != 2) continue;
      if (nowMin >= _parseTime(range[0]) && nowMin < _parseTime(range[1])) {
        return s.id;
      }
    }
    return sessions.isNotEmpty ? sessions.first.id : null;
  }

  int _parseTime(String t) {
    t = t.toLowerCase().replaceAll(' ', '');
    final isPm = t.contains('pm');
    t = t.replaceAll('pm', '').replaceAll('am', '');
    final p = t.split(':');
    int h = int.parse(p[0]);
    final m = p.length > 1 ? int.parse(p[1]) : 0;
    if (isPm && h != 12) h += 12;
    return h * 60 + m;
  }

  // ── Toggle task ────────────────────────────────────────────────────

  Future<void> toggleTask(String taskId) async {
    final current = state.value;
    if (current == null) return;

    final newDone = !(current.taskStates[taskId] ?? false);
    final newDaily = current.dailyState.copyWith(
      taskStates: {...current.taskStates, taskId: newDone},
    );

    state = AsyncData(current.copyWith(dailyState: newDaily));
    await hiveService.writeDailyState(newDaily);
    supabaseService.upsertDailyState(newDaily, deviceId).catchError((_) {});

    // Update streak (fire-and-forget)
    final allDone = _areAllTasksDone(newDaily);
    streakService
        .onTaskToggled(allTasksDone: allDone)
        .catchError((_) => Streak.empty(deviceId));

    // Record stats history (fire-and-forget)
    final pct = state.value?.completionPct ?? 0;
    supabaseService
        .upsertStatsHistory(_todayKey, pct, deviceId)
        .catchError((_) {});
  }

  bool _areAllTasksDone(DailyState daily) {
    final allIds = SessionData.taskIdsForToday(
      isFriday: DayChecker.isFriday(),
      isSunday: DayChecker.isSunday(),
    );
    return allIds.isNotEmpty &&
        allIds.every((id) => daily.taskStates[id] == true);
  }

  // ── Toggle bonus ───────────────────────────────────────────────────

  Future<void> toggleBonus(String taskId) async {
    final current = state.value;
    if (current == null) return;

    final newDaily = current.dailyState.copyWith(
      bonusStates: {...current.bonusStates, taskId: !(current.bonusStates[taskId] ?? false)},
    );

    state = AsyncData(current.copyWith(dailyState: newDaily));
    await hiveService.writeDailyState(newDaily);
    supabaseService.upsertDailyState(newDaily, deviceId).catchError((_) {});
  }

  // ── Set mood ───────────────────────────────────────────────────────

  Future<void> setMood(String mood) async {
    final current = state.value;
    if (current == null) return;

    final newDaily = DailyState(
      date: current.dailyState.date,
      taskStates: current.dailyState.taskStates,
      bonusStates: current.dailyState.bonusStates,
      mood: mood,
    );

    state = AsyncData(current.copyWith(dailyState: newDaily));
    await hiveService.writeDailyState(newDaily);
    supabaseService.upsertDailyState(newDaily, deviceId).catchError((_) {});
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────────────────────

final sessionsProvider =
    AsyncNotifierProvider<SessionsNotifier, SessionsState>(
        SessionsNotifier.new);

final completionPctProvider = Provider<int>((ref) {
  return ref.watch(sessionsProvider).value?.completionPct ?? 0;
});

final activeSessionProvider = Provider<Session?>((ref) {
  return ref.watch(sessionsProvider).value?.activeSession;
});
