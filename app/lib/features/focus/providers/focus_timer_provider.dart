import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/notification_service.dart';
import '../../sessions/providers/sessions_provider.dart';
import '../../../main.dart' show sharedPrefs;

// ── SharedPrefs keys for cross-process timer persistence ─────────────────────
// savedAtMs + wasRunning lets us compute elapsed time on restart without
// having to write to disk every second.
const _kRemaining = 'focus_saved_remaining_secs';
const _kTotal     = 'focus_saved_total_secs';
const _kTitle     = 'focus_saved_task_title';
const _kTaskId    = 'focus_saved_task_id';
const _kRunning   = 'focus_was_running';
const _kSavedAt   = 'focus_saved_at_ms';

class FocusTimerState {
  final bool isRunning;
  final int remainingSeconds;
  final int totalSeconds;
  final String taskTitle;
  final String? taskId;
  final String? currentAmbient;
  final String? selectedProject;

  const FocusTimerState({
    required this.isRunning,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.taskTitle = '',
    this.taskId,
    this.currentAmbient,
    this.selectedProject,
  });

  FocusTimerState copyWith({
    bool? isRunning,
    int? remainingSeconds,
    int? totalSeconds,
    String? taskTitle,
    String? taskId,
    String? currentAmbient,
    String? selectedProject,
    bool clearAmbient = false,
    bool clearProject = false,
  }) {
    return FocusTimerState(
      isRunning: isRunning ?? this.isRunning,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      taskTitle: taskTitle ?? this.taskTitle,
      taskId: taskId ?? this.taskId,
      currentAmbient:
          clearAmbient ? null : (currentAmbient ?? this.currentAmbient),
      selectedProject:
          clearProject ? null : (selectedProject ?? this.selectedProject),
    );
  }
}

class FocusTimerNotifier extends Notifier<FocusTimerState> {
  Timer? _timer;
  DateTime? _backgroundPauseTime;

  @override
  FocusTimerState build() {
    ref.onDispose(() => _timer?.cancel());
    // Restore an interrupted session from SharedPrefs, or start fresh.
    return _loadSavedState() ??
        const FocusTimerState(
          isRunning: false,
          remainingSeconds: 25 * 60,
          totalSeconds: 25 * 60,
        );
  }

  // ── Persistence helpers ───────────────────────────────────────────────────

  /// Reads SharedPrefs and reconstructs a paused FocusTimerState.
  ///
  /// If the timer was running when the app was killed, the elapsed time since
  /// [_kSavedAt] is subtracted from [_kRemaining]. Returns null when:
  ///   • no saved state exists (fresh install / after stopTimer)
  ///   • the timer already expired while the app was dead
  FocusTimerState? _loadSavedState() {
    final savedRemaining = sharedPrefs.getInt(_kRemaining);
    if (savedRemaining == null) return null;

    final savedTotal  = sharedPrefs.getInt(_kTotal) ?? savedRemaining;
    final taskTitle   = sharedPrefs.getString(_kTitle) ?? '';
    final taskId      = sharedPrefs.getString(_kTaskId);
    final wasRunning  = sharedPrefs.getBool(_kRunning) ?? false;
    final savedAtMs   = sharedPrefs.getInt(_kSavedAt) ?? 0;

    int adjustedRemaining = savedRemaining;

    if (wasRunning) {
      // Subtract wall-clock time elapsed since we last saved the timestamp.
      // This handles both normal kills and kills while backgrounded.
      final elapsedSecs =
          (DateTime.now().millisecondsSinceEpoch - savedAtMs) ~/ 1000;
      adjustedRemaining = savedRemaining - elapsedSecs;

      if (adjustedRemaining <= 0) {
        // Timer finished while the app was dead — can't credit focus minutes
        // from inside build(), so just clear and fall through to default.
        _clearSavedState();
        return null;
      }
    }

    // Always restore as PAUSED — user must press play to resume (agreed UX).
    return FocusTimerState(
      isRunning: false,
      remainingSeconds: adjustedRemaining,
      totalSeconds: savedTotal,
      taskTitle: taskTitle,
      taskId: taskId,
    );
  }

  /// Writes the current timer state + a wall-clock timestamp to SharedPrefs.
  /// Because we store [_kSavedAt], we don't need to write every second —
  /// elapsed time is always computable on restore.
  void _saveState() {
    sharedPrefs.setInt(_kRemaining, state.remainingSeconds);
    sharedPrefs.setInt(_kTotal, state.totalSeconds);
    sharedPrefs.setString(_kTitle, state.taskTitle);
    sharedPrefs.setBool(_kRunning, state.isRunning);
    sharedPrefs.setInt(_kSavedAt, DateTime.now().millisecondsSinceEpoch);
    if (state.taskId != null) {
      sharedPrefs.setString(_kTaskId, state.taskId!);
    } else {
      sharedPrefs.remove(_kTaskId);
    }
  }

  /// Removes all saved timer keys — called when the session is deliberately stopped.
  void _clearSavedState() {
    sharedPrefs.remove(_kRemaining);
    sharedPrefs.remove(_kTotal);
    sharedPrefs.remove(_kTitle);
    sharedPrefs.remove(_kTaskId);
    sharedPrefs.remove(_kRunning);
    sharedPrefs.remove(_kSavedAt);
  }

  // ── Public API ────────────────────────────────────────────────────────────

  void initTimer({
    required String taskTitle,
    required int durationMinutes,
    String? taskId,
  }) {
    final isSameTask = state.taskTitle == taskTitle;
    final isTimerActive = state.isRunning ||
        (state.remainingSeconds > 0 &&
            state.remainingSeconds < state.totalSeconds);

    // Keep progress if this is the same task with an active/paused timer.
    if (isSameTask && isTimerActive) return;

    state = state.copyWith(
      taskTitle: taskTitle,
      taskId: taskId,
      totalSeconds: durationMinutes * 60,
      remainingSeconds: durationMinutes * 60,
    );
  }

  void startTimer({required VoidCallback onComplete}) {
    if (state.isRunning) return;
    state = state.copyWith(isRunning: true);

    // Persist immediately — savedAt timestamp enables elapsed-time correction
    // on any future restart without writing to disk on every tick.
    _saveState();

    final endTime = DateTime.now().add(Duration(seconds: state.remainingSeconds));
    notificationService.scheduleFocusAlarm(state.taskTitle, endTime);
    notificationService.showOngoingFocus(state.taskTitle);

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.remainingSeconds > 0) {
        state = state.copyWith(remainingSeconds: state.remainingSeconds - 1);
        // Periodically persist so _kSavedAt stays fresh.
        // This guards against OS-level process suspension that may not
        // trigger the paused lifecycle event before a hard kill.
        if (state.remainingSeconds % 30 == 0) {
          _saveState();
        }
      } else {
        final totalMins    = state.totalSeconds ~/ 60;
        final selectedTag  = state.selectedProject;
        final taskId       = state.taskId;

        stopTimer();

        ref.read(sessionsProvider.notifier).addFocusMinutes(
          totalMins,
          tag: selectedTag,
          taskId: taskId,
        );

        onComplete();
      }
    });
  }

  void pauseTimer() {
    _timer?.cancel();
    notificationService.cancelFocusAlarm();
    notificationService.showOngoingFocusPaused(state.taskTitle);
    state = state.copyWith(isRunning: false);
    // Save paused state so a subsequent kill remembers remaining seconds
    // without any elapsed-time deduction (wasRunning = false).
    _saveState();
  }

  void stopTimer() {
    _timer?.cancel();
    notificationService.cancelFocusAlarm();
    notificationService.cancelOngoingFocus();
    state = state.copyWith(
      isRunning: false,
      remainingSeconds: state.totalSeconds,
    );
    // Session deliberately ended — wipe persistence so next app open is fresh.
    _clearSavedState();
  }

  void changeDuration(int minutes) {
    if (state.isRunning) return;
    final secs = minutes * 60;
    state = state.copyWith(totalSeconds: secs, remainingSeconds: secs);
  }

  void toggleAmbient(String sound) {
    if (state.currentAmbient == sound) {
      state = state.copyWith(clearAmbient: true);
    } else {
      state = state.copyWith(currentAmbient: sound);
    }
  }

  void setAmbient(String sound) {
    if (sound == 'none') {
      state = state.copyWith(clearAmbient: true);
    } else {
      state = state.copyWith(currentAmbient: sound);
    }
  }

  void setSelectedProject(String? project) {
    if (project == null) {
      state = state.copyWith(clearProject: true);
    } else {
      state = state.copyWith(selectedProject: project);
    }
  }

  void backgroundPause() {
    if (state.isRunning) {
      _backgroundPauseTime = DateTime.now();
      _timer?.cancel();
      // Save with wasRunning=true + fresh timestamp so a kill while backgrounded
      // still computes elapsed time correctly on next launch.
      _saveState();
    }
  }

  void backgroundResume({required VoidCallback onComplete}) {
    if (state.isRunning && _backgroundPauseTime != null) {
      final diff = DateTime.now().difference(_backgroundPauseTime!).inSeconds;
      final newRemaining = state.remainingSeconds - diff;

      _backgroundPauseTime = null;

      if (newRemaining <= 0) {
        state = state.copyWith(remainingSeconds: 0);

        final totalMins   = state.totalSeconds ~/ 60;
        final selectedTag = state.selectedProject;
        final taskId      = state.taskId;

        stopTimer();

        ref.read(sessionsProvider.notifier).addFocusMinutes(
          totalMins,
          tag: selectedTag,
          taskId: taskId,
        );

        onComplete();
      } else {
        // isRunning must be false for startTimer to proceed.
        state = state.copyWith(remainingSeconds: newRemaining, isRunning: false);
        startTimer(onComplete: onComplete); // startTimer calls _saveState() with new timestamp
      }
    }
  }
}

final focusTimerProvider =
    NotifierProvider<FocusTimerNotifier, FocusTimerState>(
  FocusTimerNotifier.new,
);
