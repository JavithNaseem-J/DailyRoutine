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
import '../../../main.dart' show deviceId;

// SessionsState

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

  // BUG-014 fix: guard against empty sessions list before calling .first
  SessionPillState pillState(String sessionId) {
    if (sessions.isEmpty) return SessionPillState.empty;
    final session = sessions.firstWhere(
      (s) => s.id == sessionId,
      orElse: () => sessions.first,
    );
    final validTasks = session.tasks
        .where((t) => !t.isBreak)
        .map((t) => t.id)
        .toList();
    if (validTasks.isEmpty) return SessionPillState.empty;
    final doneCount = validTasks.where((id) => taskStates[id] == true).length;
    final skippedCount = validTasks
        .where((id) => dailyState.taskStatus[id] == 'skipped')
        .length;
    final totalValid = validTasks.length - skippedCount;
    if (totalValid == 0) {
      return skippedCount > 0
          ? SessionPillState.complete
          : SessionPillState.empty;
    }
    if (doneCount == totalValid) return SessionPillState.complete;
    if (doneCount / totalValid >= 0.5) return SessionPillState.halfway;
    return SessionPillState.started;
  }

  bool isSessionComplete(String sessionId) =>
      pillState(sessionId) == SessionPillState.complete;

  int get completionPct {
    final validTasks = sessions
        .expand((s) => s.tasks)
        .where((t) => !t.isBreak)
        .map((t) => t.id)
        .toSet()
        .toList();
    if (validTasks.isEmpty) return 0;
    final doneCount = validTasks.where((id) => taskStates[id] == true).length;
    return ((doneCount / validTasks.length) * 100).round();
  }

  // BUG-002 fix: return null instead of crashing when sessions is empty
  Session? get activeSession {
    if (sessions.isEmpty) return null;
    return sessions.firstWhere(
      (s) => s.id == (activeSessionId ?? ''),
      orElse: () => sessions.first,
    );
  }

  SessionsState copyWith({DailyState? dailyState, List<Session>? sessions}) =>
      SessionsState(
        dailyState: dailyState ?? this.dailyState,
        sessions: sessions ?? this.sessions,
        activeSessionId: activeSessionId,
      );
}

// SessionsNotifier  (Riverpod 3.x — state is AsyncValue<SessionsState>)

class SessionsNotifier extends AsyncNotifier<SessionsState> {
  String get _todayKey => dateService.todayKey();

  List<Session> _buildSessionsWithResurfacing(
    DailyState dailyState,
    List<Task> allCustomTasks,
    String? activeSessionId,
  ) {
    final today = DateTime.now();
    final baseSessions = SessionData.sessionsForDate(today);

    // Session display order for key task resurfacing (weekday sessions only)
    const sessionOrder = {
      'morning': 0,
      'afternoon': 1,
      'night': 2,
      'saturday': 3,
      'sunday': 4,
    };

    // Migrate legacy 'weekend' tasks to 'saturday'
    final migratedTasks = allCustomTasks.map((t) {
      if (t.sessionId == 'weekend') return t.copyWith(sessionId: 'saturday');
      return t;
    }).toList();

    // 1. Build normal sessions with their own tasks, filtered by weekday
    final List<Session> normalSessions = baseSessions.map((s) {
      final relevantTasks = migratedTasks
          .where((t) {
            if (t.sessionId != s.id) return false;
            // Weekday filter: empty weekdays = active every day
            return t.weekdays.isEmpty || t.weekdays.contains(today.weekday);
          })
          .toList();
      relevantTasks.sort(
        (a, b) => _parseTime(a.time).compareTo(_parseTime(b.time)),
      );
      return Session(
        id: s.id,
        name: s.name,
        timeRange: s.timeRange,
        accentColor: s.accentColor,
        tasks: [...s.tasks, ...relevantTasks],
        isFridayOnly: s.isFridayOnly,
        isWeekendOnly: s.isWeekendOnly,
      );
    }).toList();

    // 2. Apply key task resurfacing: only append missed key tasks to the 'key_tasks' session
    return normalSessions.map((s) {
      if (s.id == 'key_tasks') {
        final resurfaced = migratedTasks.where((t) {
          if (!t.isKeyTask) return false;
          // Key tasks only resurface if they were active today
          if (t.weekdays.isNotEmpty && !t.weekdays.contains(today.weekday)) return false;

          final tOrder = sessionOrder[t.sessionId];
          final activeOrder = sessionOrder[activeSessionId];
          if (tOrder == null || activeOrder == null) return false;
          if (tOrder >= activeOrder) return false; // not from an earlier session

          final isDone = dailyState.taskStates[t.id] == true;
          final isSkipped = dailyState.taskStatus[t.id] == 'skipped';
          final isMissed = !isDone || isSkipped;

          return isMissed;
        }).toList();

        return Session(
          id: s.id,
          name: s.name,
          timeRange: s.timeRange,
          accentColor: s.accentColor,
          tasks: [...s.tasks, ...resurfaced],
          isFridayOnly: s.isFridayOnly,
          isWeekendOnly: s.isWeekendOnly,
        );
      } else {
        // No resurfacing into other normal sessions
        return s;
      }
    }).toList();
  }

  @override
  Future<SessionsState> build() async {
    final defaultSessions = SessionData.sessionsForToday;

    // 1. Load from Hive instantly
    final daily = hiveService.readDailyState(_todayKey);
    final customTasks = hiveService.readCustomTasks();
    final activeSessId = _findActiveSessionId(defaultSessions);

    final sessions = _buildSessionsWithResurfacing(
      daily,
      customTasks,
      activeSessId,
    );

    // 2. Refresh from Supabase in the background
    _refreshFromSupabase(daily, sessions);

    return SessionsState(
      dailyState: daily,
      sessions: sessions,
      activeSessionId: activeSessId,
    );
  }

  Future<void> _refreshFromSupabase(
    DailyState localState,
    List<Session> defaultSessions,
  ) async {
    final remote = await supabaseService.fetchDailyState(_todayKey, deviceId);
    final remoteCustomTasks = await supabaseService.fetchCustomTasks(deviceId);
    final localCustomTasks = hiveService.readCustomTasks();

    // Merge remote and local custom tasks:
    // If a task exists in both, remote should win.
    // If a task exists only locally, upload it to remote!
    final Map<String, Task> mergedMap = {};
    for (final task in localCustomTasks) {
      mergedMap[task.id] = task;
    }
    for (final task in remoteCustomTasks) {
      mergedMap[task.id] = task;
    }
    
    final mergedList = mergedMap.values.toList();
    
    // Upload local-only tasks to remote
    for (final task in localCustomTasks) {
      final existsOnRemote = remoteCustomTasks.any((t) => t.id == task.id);
      if (!existsOnRemote) {
        await supabaseService.upsertCustomTask(task, deviceId).catchError((_) {});
      }
    }
    
    // Save merged to Hive
    await hiveService.writeCustomTasks(mergedList);

    DailyState merged;
    if (remote == null) {
      merged = localState;
    } else {
      merged = DailyState(
        date: _todayKey,
        taskStates: {...localState.taskStates, ...remote.taskStates},
        taskStatus: {...localState.taskStatus, ...remote.taskStatus},
        bonusStates: {...localState.bonusStates, ...remote.bonusStates},
        prayerStates: {...localState.prayerStates, ...remote.prayerStates},
        mood: remote.mood ?? localState.mood,
        focusMinutes: remote.focusMinutes > localState.focusMinutes
            ? remote.focusMinutes
            : localState.focusMinutes,
        focusSessions: remote.focusSessions.isNotEmpty
            ? remote.focusSessions
            : localState.focusSessions,
        projectMinutes: {
          ...localState.projectMinutes,
          ...remote.projectMinutes,
        },
      );
      await hiveService.writeDailyState(merged);
    }

    final current = state.value;
    if (current != null) {
      final activeSessId = _findActiveSessionId(SessionData.sessionsForToday);
      final updatedSessions = _buildSessionsWithResurfacing(
        merged,
        mergedList,
        activeSessId,
      );

      state = AsyncData(
        current.copyWith(dailyState: merged, sessions: updatedSessions),
      );
    }
  }

  String? _findActiveSessionId(List<Session> sessions) {
    final now = TimeOfDay.now();
    final nowMin = now.hour * 60 + now.minute;
    for (final s in sessions) {
      final range = s.timeRange
          .split(RegExp(r'\s*[-–—]\s*'))
          .map((p) => p.trim())
          .toList();
      if (range.length != 2) continue;
      if (nowMin >= _parseTime(range[0]) && nowMin < _parseTime(range[1])) {
        return s.id;
      }
    }
    return sessions.isNotEmpty ? sessions.first.id : null;
  }

  int _parseTime(String t) {
    t = t.toLowerCase().replaceAll(' ', '');
    if (t == 'allday' || t.isEmpty) return 0;
    final isPm = t.contains('pm');
    final isAm = t.contains('am');
    t = t.replaceAll('pm', '').replaceAll('am', '');
    final p = t.split(':');
    int h = int.tryParse(p[0]) ?? 0;
    final m = p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0;
    if (isPm && h != 12) h += 12;
    if (isAm && h == 12) h = 0;
    return h * 60 + m;
  }

  Future<void> toggleTask(String taskId) async {
    final current = state.value;
    if (current == null) return;

    final currentDone = current.taskStates[taskId] ?? false;
    final currentStatus = current.dailyState.taskStatus[taskId] ?? 'none';

    bool newDone = false;
    String newStatus = 'none';

    if (!currentDone && currentStatus != 'skipped') {
      // Pending -> Completed
      newDone = true;
      Task? targetTask;
      for (final s in current.sessions) {
        targetTask = s.tasks.where((t) => t.id == taskId).firstOrNull;
        if (targetTask != null) break;
      }

      if (targetTask != null) {
        final startMin = _parseTime(targetTask.time);
        final endMin = startMin + targetTask.durationMinutes;
        final now = TimeOfDay.now();
        final nowMin = now.hour * 60 + now.minute;

        if (nowMin <= endMin) {
          newStatus = 'on_time';
        } else {
          newStatus = 'late';
        }
      } else {
        newStatus = 'on_time';
      }
    } else if (currentDone) {
      // Completed -> Skipped
      newDone = false;
      newStatus = 'skipped';
    } else if (currentStatus == 'skipped') {
      // Skipped -> Pending
      newDone = false;
      newStatus = 'none';
    }

    await _applyTaskStatusChange(current, taskId, newDone, newStatus);
  }

  Future<void> setExplicitTaskStatus(String taskId, String newStatus) async {
    final current = state.value;
    if (current == null) return;

    // newStatus should be 'on_time', 'late', 'skipped', or 'none'
    bool newDone = (newStatus == 'on_time' || newStatus == 'late');

    await _applyTaskStatusChange(current, taskId, newDone, newStatus);
  }

  Future<void> _applyTaskStatusChange(
    SessionsState current,
    String taskId,
    bool newDone,
    String newStatus,
  ) async {
    final newDaily = current.dailyState.copyWith(
      taskStates: {...current.taskStates, taskId: newDone},
      taskStatus: {...current.dailyState.taskStatus, taskId: newStatus},
    );

    final customTasks = hiveService.readCustomTasks();
    final updatedSessions = _buildSessionsWithResurfacing(
      newDaily,
      customTasks,
      current.activeSessionId,
    );

    state = AsyncData(current.copyWith(dailyState: newDaily, sessions: updatedSessions));
    await hiveService.writeDailyState(newDaily);
    supabaseService.upsertDailyState(newDaily, deviceId).catchError((_) {});

    // Update streak (fire-and-forget)
    final streakAchieved = _isStreakAchieved(newDaily);
    streakService
        .onTaskToggled(allTasksDone: streakAchieved)
        .catchError((_) => Streak.empty(deviceId));

    // Record stats history (fire-and-forget)
    final pct = state.value?.completionPct ?? 0;
    supabaseService
        .upsertStatsHistory(_todayKey, pct, deviceId)
        .catchError((_) {});
  }

  bool _isStreakAchieved(DailyState daily) {
    final current = state.value;
    if (current == null) return false;
    final validTasks = current.sessions
        .expand((s) => s.tasks)
        .where((t) => !t.isBreak)
        .map((t) => t.id)
        .toSet()
        .toList();
    if (validTasks.isEmpty) return false;
    final doneCount = validTasks
        .where((id) => daily.taskStates[id] == true)
        .length;
    final pct = ((doneCount / validTasks.length) * 100).round();
    return pct >= 50;
  }

  Future<void> toggleBonus(String taskId) async {
    final current = state.value;
    if (current == null) return;

    final newDaily = current.dailyState.copyWith(
      bonusStates: {
        ...current.bonusStates,
        taskId: !(current.bonusStates[taskId] ?? false),
      },
    );

    state = AsyncData(current.copyWith(dailyState: newDaily));
    await hiveService.writeDailyState(newDaily);
    supabaseService.upsertDailyState(newDaily, deviceId).catchError((_) {});
  }

  Future<void> togglePrayer(String prayerName) async {
    final current = state.value;
    if (current == null) return;

    final key = prayerName.toLowerCase();
    final newDaily = current.dailyState.copyWith(
      prayerStates: {
        ...current.dailyState.prayerStates,
        key: !(current.dailyState.prayerStates[key] ?? false),
      },
    );

    state = AsyncData(current.copyWith(dailyState: newDaily));
    await hiveService.writeDailyState(newDaily);
    supabaseService.upsertDailyState(newDaily, deviceId).catchError((_) {});
  }

  // BUG-005 fix: use copyWith so prayerStates and all fields are preserved
  Future<void> setMood(String mood) async {
    final current = state.value;
    if (current == null) return;

    final newDaily = current.dailyState.copyWith(mood: mood);

    state = AsyncData(current.copyWith(dailyState: newDaily));
    await hiveService.writeDailyState(newDaily);
    supabaseService.upsertDailyState(newDaily, deviceId).catchError((_) {});
  }

  Future<void> updateJobApplicationsCount(int count) async {
    final current = state.value;
    if (current == null) return;

    final newDaily = current.dailyState.copyWith(jobApplicationsCount: count);

    state = AsyncData(current.copyWith(dailyState: newDaily));
    await hiveService.writeDailyState(newDaily);
    supabaseService.upsertDailyState(newDaily, deviceId).catchError((_) {});
  }

  Future<void> addFocusMinutes(int minutes, {String? tag, String? taskId}) async {
    final current = state.value;
    if (current == null) return;

    final updatedProject = Map<String, int>.from(
      current.dailyState.projectMinutes,
    );
    if (tag != null && tag.isNotEmpty) {
      updatedProject[tag] = (updatedProject[tag] ?? 0) + minutes;
    }
    if (taskId != null && taskId.isNotEmpty) {
      final key = 'task_fm:$taskId';
      updatedProject[key] = (updatedProject[key] ?? 0) + minutes;
    }

    // Append this individual session to the sessions log
    final updatedSessions = List<int>.from(current.dailyState.focusSessions)
      ..add(minutes);

    final newDaily = current.dailyState.copyWith(
      focusMinutes: current.dailyState.focusMinutes + minutes,
      focusSessions: updatedSessions,
      projectMinutes: updatedProject,
    );

    state = AsyncData(current.copyWith(dailyState: newDaily));
    await hiveService.writeDailyState(newDaily);
    supabaseService.upsertDailyState(newDaily, deviceId).catchError((_) {});
  }

  Future<void> addCustomTask(Task task) async {
    final currentTasks = hiveService.readCustomTasks();
    currentTasks.add(task);
    await hiveService.writeCustomTasks(currentTasks);
    supabaseService.upsertCustomTask(task, deviceId).catchError((_) {});

    final current = state.value;
    if (current == null) return;

    final updatedSessions = _buildSessionsWithResurfacing(
      current.dailyState,
      currentTasks,
      current.activeSessionId,
    );

    state = AsyncData(current.copyWith(sessions: updatedSessions));
  }

  Future<void> editCustomTask(Task updatedTask, String oldSessionId) async {
    final customTasks = hiveService.readCustomTasks();
    final idx = customTasks.indexWhere((t) => t.id == updatedTask.id);
    if (idx != -1) {
      customTasks[idx] = updatedTask;
      await hiveService.writeCustomTasks(customTasks);
      supabaseService
          .upsertCustomTask(updatedTask, deviceId)
          .catchError((_) {});
    }

    final current = state.value;
    if (current == null) return;

    final updatedSessions = _buildSessionsWithResurfacing(
      current.dailyState,
      customTasks,
      current.activeSessionId,
    );

    state = AsyncData(current.copyWith(sessions: updatedSessions));
  }

  Future<void> deleteCustomTask(String taskId, String sessionId) async {
    final customTasks = hiveService.readCustomTasks();
    customTasks.removeWhere((t) => t.id == taskId);
    await hiveService.writeCustomTasks(customTasks);
    supabaseService.deleteCustomTask(taskId).catchError((_) {});

    final current = state.value;
    if (current == null) return;

    final updatedSessions = _buildSessionsWithResurfacing(
      current.dailyState,
      customTasks,
      current.activeSessionId,
    );

    state = AsyncData(current.copyWith(sessions: updatedSessions));
  }
}

final sessionsProvider = AsyncNotifierProvider<SessionsNotifier, SessionsState>(
  SessionsNotifier.new,
);

final completionPctProvider = Provider<int>((ref) {
  return ref.watch(sessionsProvider).value?.completionPct ?? 0;
});

final activeSessionProvider = Provider<Session?>((ref) {
  return ref.watch(sessionsProvider).value?.activeSession;
});
