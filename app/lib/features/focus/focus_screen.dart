import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_colors.dart';
import '../sessions/providers/sessions_provider.dart';

import 'providers/focus_timer_provider.dart';

class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({
    super.key,
    required this.taskTitle,
    required this.durationMinutes,
  });

  final String taskTitle;
  final int durationMinutes;

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _ambientPlayer = AudioPlayer();

  static const _sounds = {
    'rain':  'sounds/rain.wav',
    'noise': 'sounds/noise.wav',
    'cafe':  'sounds/cafe.wav',
  };

  final List<String> _projectTags = [
    'Study',
    'Work',
    'Reflect',
    'Deep Work',
    'Review',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(focusTimerProvider.notifier).initTimer(
            taskTitle: widget.taskTitle,
            durationMinutes: widget.durationMinutes,
          );
      _syncAmbientSound();
    });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _ambientPlayer.setReleaseMode(ReleaseMode.loop);
  }

  void _syncAmbientSound() async {
    final state = ref.read(focusTimerProvider);
    if (state.currentAmbient != null && state.currentAmbient != 'none') {
      try {
        await _ambientPlayer.play(AssetSource(_sounds[state.currentAmbient]!), volume: 0.5);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Automatically pause the timer when leaving the screen
    // We remove the auto pause so focus timer can continue running while user navigates other parts.
    // ref.read(focusTimerProvider.notifier).pauseTimer();
    
    _pulseController.dispose();
    _audioPlayer.dispose();
    _ambientPlayer.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      ref.read(focusTimerProvider.notifier).backgroundPause();
    } else if (state == AppLifecycleState.resumed) {
      ref.read(focusTimerProvider.notifier).backgroundResume(
        onComplete: _onTimerComplete
      );
    }
  }

  void _onTimerComplete() {
    _pulseController.stop();
    HapticFeedback.heavyImpact();
    _audioPlayer.play(
      AssetSource('sounds/timer_done.wav'),
    ).catchError((_) {});
    
    final state = ref.read(focusTimerProvider);
    ref
        .read(sessionsProvider.notifier)
        .addFocusMinutes(state.totalSeconds ~/ 60, tag: state.selectedProject);
  }

  void _toggleAmbient(String id) async {
    HapticFeedback.lightImpact();
    final notifier = ref.read(focusTimerProvider.notifier);
    notifier.toggleAmbient(id);
    final currentState = ref.read(focusTimerProvider);

    await _ambientPlayer.stop();
    if (currentState.currentAmbient != null && currentState.currentAmbient != 'none') {
      try {
        await _ambientPlayer.play(AssetSource(_sounds[currentState.currentAmbient]!), volume: 0.5);
      } catch (_) {}
    }
  }

  void _toggleTimer() {
    HapticFeedback.lightImpact();
    final state = ref.read(focusTimerProvider);
    final notifier = ref.read(focusTimerProvider.notifier);

    if (state.isRunning) {
      notifier.pauseTimer();
      _pulseController.stop();
    } else {
      _pulseController.repeat(reverse: true);
      notifier.startTimer(
        onComplete: _onTimerComplete,
      );
    }
  }

  void _changeDuration(int minutes) {
    if (ref.read(focusTimerProvider).isRunning) return;
    ref.read(focusTimerProvider.notifier).changeDuration(minutes);
    HapticFeedback.selectionClick();
  }

  String _timeString(int remainingSeconds) {
    final m = remainingSeconds ~/ 60;
    final s = remainingSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final timerState = ref.watch(focusTimerProvider);
    
    // Sync pulse animation state just in case it got out of sync
    if (timerState.isRunning && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!timerState.isRunning && _pulseController.isAnimating) {
      _pulseController.stop();
    }

    final progress = timerState.totalSeconds > 0
        ? 1 - (timerState.remainingSeconds / timerState.totalSeconds)
        : 0.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary, size: 32),
          onPressed: () {
            // BUG-004 fix: instead of stopping the timer, just pop so the user can navigate away.
            context.pop();
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              // BUG-013 fix: use kToolbarHeight constant instead of constructing a throwaway AppBar
              minHeight: MediaQuery.of(context).size.height -
                  kToolbarHeight -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
            ),
            child: IntrinsicHeight(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 16),
                  Text(
                    'F O C U S   M O D E',
                    style: AppTypography.mono(
                      size: 14,
                      weight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    timerState.taskTitle,
                    textAlign: TextAlign.center,
                    style: AppTypography.screenTitle(color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _projectTags.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final tag = _projectTags[index];
                        final isSelected = timerState.selectedProject == tag;
                        return GestureDetector(
                          onTap: () {
                            if (!timerState.isRunning) {
                              HapticFeedback.selectionClick();
                              ref.read(focusTimerProvider.notifier).setSelectedProject(
                                isSelected ? null : tag,
                              );
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.complete
                                  : AppColors.surfaceRaised,
                              borderRadius: BorderRadius.circular(19),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.complete
                                    : AppColors.border,
                              ),
                            ),
                            child: Text(
                              tag,
                              style: AppTypography.body(
                                size: 13,
                                weight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 40),

                  GestureDetector(
                    onTap: _toggleTimer,
                    child: AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: timerState.isRunning ? _pulseAnimation.value : 1.0,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 260,
                                height: 260,
                                child: CircularProgressIndicator(
                                  value: 1.0,
                                  strokeWidth: 8,
                                  valueColor: AlwaysStoppedAnimation(
                                    AppColors.surfaceRaised,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 260,
                                height: 260,
                                child: CircularProgressIndicator(
                                  value: progress.toDouble(),
                                  strokeWidth: 8,
                                  strokeCap: StrokeCap.round,
                                  valueColor: AlwaysStoppedAnimation(
                                    timerState.isRunning
                                        ? AppColors.complete
                                        : AppColors.afternoon,
                                  ),
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _timeString(timerState.remainingSeconds),
                                    style: AppTypography.mono(
                                      size: 58,
                                      weight: FontWeight.w300,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Icon(
                                    timerState.isRunning
                                        ? Icons.pause_circle_outline
                                        : Icons.play_circle_outline,
                                    color: AppColors.textSecondary,
                                    size: 30,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 48),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _DurationToggle(
                        label: '15M',
                        isSelected: timerState.totalSeconds == 15 * 60,
                        onTap: () => _changeDuration(15),
                      ),
                      const SizedBox(width: 12),
                      _DurationToggle(
                        label: '25M',
                        isSelected: timerState.totalSeconds == 25 * 60,
                        onTap: () => _changeDuration(25),
                      ),
                      const SizedBox(width: 12),
                      _DurationToggle(
                        label: '1H',
                        isSelected: timerState.totalSeconds == 60 * 60,
                        onTap: () => _changeDuration(60),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _AmbientToggle(
                        icon: Icons.water_drop,
                        label: 'Rain',
                        isSelected: timerState.currentAmbient == 'rain',
                        onTap: () => _toggleAmbient('rain'),
                      ),
                      const SizedBox(width: 12),
                      _AmbientToggle(
                        icon: Icons.waves,
                        label: 'Noise',
                        isSelected: timerState.currentAmbient == 'noise',
                        onTap: () => _toggleAmbient('noise'),
                      ),
                      const SizedBox(width: 12),
                      _AmbientToggle(
                        icon: Icons.coffee,
                        label: 'Cafe',
                        isSelected: timerState.currentAmbient == 'cafe',
                        onTap: () => _toggleAmbient('cafe'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 12,
                    ),
                    color: AppColors.surfaceRaised,
                    borderRadius: BorderRadius.circular(30),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      ref.read(focusTimerProvider.notifier).stopTimer();
                      ref.read(focusTimerProvider.notifier).setAmbient('none');
                      _pulseController.stop();
                      _ambientPlayer.stop();
                    },
                    child: Text(
                      'Reset',
                      style: AppTypography.body(
                        size: 16,
                        weight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  // Extra padding to prevent nav bar overlap
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DurationToggle extends StatelessWidget {
  const _DurationToggle({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.complete : AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: AppTypography.body(
            size: 14,
            weight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _AmbientToggle extends StatelessWidget {
  const _AmbientToggle({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.15)
              : AppColors.surfaceRaised,
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.body(
                size: 13,
                weight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
