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
    required this.selectedDate,
  });

  final DailyState dailyState;
  final List<Session> sessions;
  final String? activeSessionId;
  final String selectedDate;

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

  SessionsState copyWith({
    DailyState? dailyState,
    List<Session>? sessions,
    String? selectedDate,
  }) =>
      SessionsState(
        dailyState: dailyState ?? this.dailyState,
        sessions: sessions ?? this.sessions,
        activeSessionId: activeSessionId,
        selectedDate: selectedDate ?? this.selectedDate,
      );
}

// SessionsNotifier  (Riverpod 3.x — state is AsyncValue<SessionsState>)

class SessionsNotifier extends AsyncNotifier<SessionsState> {

  List<Session> _buildSessionsWithResurfacing(
    DailyState dailyState,
    List<Task> allCustomTasks,
    String? activeSessionId,
    String dateKey,
  ) {
    final date = DateTime.tryParse(dateKey) ?? DateTime.now();
    final baseSessions = SessionData.sessionsForDate(date);

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
            return t.weekdays.isEmpty || t.weekdays.contains(date.weekday);
          })
          .toList();
      final combinedTasks = [...s.tasks, ...relevantTasks];
      combinedTasks.sort(_compareTasks);
      return Session(
        id: s.id,
        name: s.name,
        timeRange: s.timeRange,
        accentColor: s.accentColor,
        tasks: combinedTasks,
        isWeekendOnly: s.isWeekendOnly,
      );
    }).toList();

    return normalSessions;
  }

  @override
  Future<SessionsState> build() async {
    final defaultSessions = SessionData.sessionsForToday;
    final todayKey = dateService.todayKey();

    // 1. Load from Hive instantly
    final daily = hiveService.readDailyState(todayKey);
    final customTasks = hiveService.readCustomTasks();
    final activeSessId = _findActiveSessionId(defaultSessions);

    final sessions = _buildSessionsWithResurfacing(
      daily,
      customTasks,
      activeSessId,
      todayKey,
    );

    // 2. Refresh from Supabase in the background
    _refreshFromSupabase(daily, sessions, todayKey);

    return SessionsState(
      dailyState: daily,
      sessions: sessions,
      activeSessionId: activeSessId,
      selectedDate: todayKey,
    );
  }

  Future<void> changeDate(String dateKey) async {
    final date = DateTime.tryParse(dateKey) ?? DateTime.now();
    final defaultSessions = SessionData.sessionsForDate(date);
    final daily = hiveService.readDailyState(dateKey);
    final customTasks = hiveService.readCustomTasks();
    
    final todayKey = dateService.todayKey();
    final activeSessId = (dateKey == todayKey) ? _findActiveSessionId(defaultSessions) : null;

    final sessions = _buildSessionsWithResurfacing(
      daily,
      customTasks,
      activeSessId,
      dateKey,
    );

    state = AsyncData(SessionsState(
      dailyState: daily,
      sessions: sessions,
      activeSessionId: activeSessId,
      selectedDate: dateKey,
    ));

    _refreshFromSupabase(daily, sessions, dateKey);
  }

  Future<void> _refreshFromSupabase(
    DailyState localState,
    List<Session> defaultSessions,
    String dateKey,
  ) async {
    final remote = await supabaseService.fetchDailyState(dateKey, deviceId);
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
      // Read the live in-memory state at merge time instead of the stale
      // `localState` snapshot captured at build() / changeDate() call.
      // This prevents race conditions where the user taps the job-hunt counter
      // (or toggles a task) while the async Supabase fetch is in flight —
      // those in-flight changes would otherwise be silently overwritten.
      final liveLocal = (state.value?.selectedDate == dateKey
          ? state.value?.dailyState
          : null) ?? localState;

      merged = DailyState(
        date: dateKey,
        taskStates: {...liveLocal.taskStates, ...remote.taskStates},
        taskStatus: {...liveLocal.taskStatus, ...remote.taskStatus},
        bonusStates: {...liveLocal.bonusStates, ...remote.bonusStates},
        prayerStates: {...liveLocal.prayerStates, ...remote.prayerStates},
        mood: remote.mood ?? liveLocal.mood,
        focusMinutes: remote.focusMinutes > liveLocal.focusMinutes
            ? remote.focusMinutes
            : liveLocal.focusMinutes,
        focusSessions: remote.focusSessions.isNotEmpty
            ? remote.focusSessions
            : liveLocal.focusSessions,
        projectMinutes: {
          ...liveLocal.projectMinutes,
          ...remote.projectMinutes,
        },
        // Take the higher value so a tap that hasn't synced yet is never lost.
        jobApplicationsCount: remote.jobApplicationsCount > liveLocal.jobApplicationsCount
            ? remote.jobApplicationsCount
            : liveLocal.jobApplicationsCount,
      );
      await hiveService.writeDailyState(merged);
    }

    final current = state.value;
    if (current != null && current.selectedDate == dateKey) {
      final date = DateTime.tryParse(dateKey) ?? DateTime.now();
      final defaultSess = SessionData.sessionsForDate(date);
      final todayKey = dateService.todayKey();
      final activeSessId = (dateKey == todayKey) ? _findActiveSessionId(defaultSess) : null;
      final updatedSessions = _buildSessionsWithResurfacing(
        merged,
        mergedList,
        activeSessId,
        dateKey,
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

  int _compareTasks(Task a, Task b) {
    int parseTimeForSort(String t) {
      t = t.toLowerCase().replaceAll(' ', '');
      if (t == 'allday' || t.isEmpty) return 99999;
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

    final timeA = parseTimeForSort(a.time);
    final timeB = parseTimeForSort(b.time);
    if (timeA != timeB) {
      return timeA.compareTo(timeB);
    }
    if (a.isUrgent != b.isUrgent) {
      return a.isUrgent ? -1 : 1;
    }
    int getPriorityRank(String? p) {
      if (p == 'P1') return 1;
      if (p == 'P2') return 2;
      if (p == 'P3') return 3;
      return 4;
    }
    final rankA = getPriorityRank(a.priority);
    final rankB = getPriorityRank(b.priority);
    if (rankA != rankB) {
      return rankA.compareTo(rankB);
    }
    final createdA = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final createdB = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return createdA.compareTo(createdB);
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
      current.selectedDate,
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
        .upsertStatsHistory(current.selectedDate, pct, deviceId)
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
      current.selectedDate,
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
      current.selectedDate,
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
      current.selectedDate,
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
