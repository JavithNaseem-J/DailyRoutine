import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/notification_service.dart';
import '../../sessions/providers/sessions_provider.dart';


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
      currentAmbient: clearAmbient ? null : (currentAmbient ?? this.currentAmbient),
      selectedProject: clearProject ? null : (selectedProject ?? this.selectedProject),
    );
  }
}

class FocusTimerNotifier extends Notifier<FocusTimerState> {
  Timer? _timer;
  DateTime? _backgroundPauseTime;

  @override
  FocusTimerState build() {
    return const FocusTimerState(
      isRunning: false,
      remainingSeconds: 25 * 60,
      totalSeconds: 25 * 60,
    );
  }

  void initTimer({required String taskTitle, required int durationMinutes, String? taskId}) {
    final isSameTask = state.taskTitle == taskTitle;
    final isTimerActive = state.isRunning || 
        (state.remainingSeconds > 0 && state.remainingSeconds < state.totalSeconds);
    
    // If we have an active or paused timer for the SAME task, keep the progress
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
    
    // Schedule robust background alarm
    final endTime = DateTime.now().add(Duration(seconds: state.remainingSeconds));
    notificationService.scheduleFocusAlarm(state.taskTitle, endTime);
    notificationService.showOngoingFocus(state.taskTitle);
    
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.remainingSeconds > 0) {
        state = state.copyWith(remainingSeconds: state.remainingSeconds - 1);
      } else {
        final totalMins = state.totalSeconds ~/ 60;
        final selectedTag = state.selectedProject;
        final taskId = state.taskId;

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
  }

  void stopTimer() {
    _timer?.cancel();
    notificationService.cancelFocusAlarm();
    notificationService.cancelOngoingFocus();
    state = state.copyWith(
      isRunning: false,
      remainingSeconds: state.totalSeconds,
    );
  }

  void changeDuration(int minutes) {
    if (state.isRunning) return;
    final secs = minutes * 60;
    state = state.copyWith(
      totalSeconds: secs,
      remainingSeconds: secs,
    );
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
    }
  }

  void backgroundResume({required VoidCallback onComplete}) {
    if (state.isRunning && _backgroundPauseTime != null) {
      final diff = DateTime.now().difference(_backgroundPauseTime!).inSeconds;
      final newRemaining = state.remainingSeconds - diff;
      
      _backgroundPauseTime = null;

      if (newRemaining <= 0) {
        state = state.copyWith(remainingSeconds: 0);
        
        final totalMins = state.totalSeconds ~/ 60;
        final selectedTag = state.selectedProject;
        final taskId = state.taskId;

        stopTimer();

        ref.read(sessionsProvider.notifier).addFocusMinutes(
          totalMins,
          tag: selectedTag,
          taskId: taskId,
        );

        onComplete();
      } else {
        // Fix: must set isRunning to false so startTimer actually runs
        state = state.copyWith(remainingSeconds: newRemaining, isRunning: false);
        startTimer(onComplete: onComplete);
      }
    }
  }
}

final focusTimerProvider = NotifierProvider<FocusTimerNotifier, FocusTimerState>(() {
  return FocusTimerNotifier();
});
