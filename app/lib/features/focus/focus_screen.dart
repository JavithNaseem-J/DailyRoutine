import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_colors.dart';
import '../sessions/providers/sessions_provider.dart';

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
    with SingleTickerProviderStateMixin {
  late int _remainingSeconds;
  late int _totalSeconds;
  Timer? _timer;
  bool _isRunning = false;
  String? _currentAmbient;
  String? _selectedProject;

  // Removed: #Code, #Quran, #Build
  final List<String> _projectTags = [
    'Study',
    'Work',
    'Reflect',
    'Deep Work',
    'Review',
  ];

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _ambientPlayer = AudioPlayer();

  // ── Working ambient sound URLs ─────────────────────────────────────────────
  static const _sounds = {
    'rain':  'sounds/rain.wav',
    'noise': 'sounds/noise.wav',
    'cafe':  'sounds/cafe.wav',
  };

  @override
  void initState() {
    super.initState();
    _totalSeconds = widget.durationMinutes * 60;
    _remainingSeconds = _totalSeconds;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _ambientPlayer.setReleaseMode(ReleaseMode.loop);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _audioPlayer.dispose();
    _ambientPlayer.dispose();
    super.dispose();
  }

  void _toggleAmbient(String id) async {
    HapticFeedback.lightImpact();
    if (_currentAmbient == id) {
      await _ambientPlayer.stop();
      setState(() => _currentAmbient = null);
    } else {
      setState(() => _currentAmbient = id);
      try {
        await _ambientPlayer.stop();
        await _ambientPlayer.play(AssetSource(_sounds[id]!), volume: 0.5);
      } catch (_) {}
    }
  }

  void _toggleTimer() {
    HapticFeedback.lightImpact();
    if (_isRunning) {
      _timer?.cancel();
      _pulseController.stop();
      setState(() => _isRunning = false);
    } else {
      _pulseController.repeat(reverse: true);
      setState(() => _isRunning = true);
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_remainingSeconds > 0) {
          setState(() => _remainingSeconds--);
        } else {
          _timer?.cancel();
          _pulseController.stop();
          setState(() => _isRunning = false);
          HapticFeedback.heavyImpact();
          _audioPlayer.play(
            AssetSource('sounds/timer_done.wav'),
          ).catchError((_) {});
          ref
              .read(sessionsProvider.notifier)
              .addFocusMinutes(_totalSeconds ~/ 60, tag: _selectedProject);
        }
      });
    }
  }

  void _changeDuration(int minutes) {
    if (_isRunning) return;
    setState(() {
      _totalSeconds = minutes * 60;
      _remainingSeconds = _totalSeconds;
    });
    HapticFeedback.selectionClick();
  }

  String get _timeString {
    final m = _remainingSeconds ~/ 60;
    final s = _remainingSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final progress = _totalSeconds > 0
        ? 1 - (_remainingSeconds / _totalSeconds)
        : 0.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: AppColors.textSecondary),
          onPressed: () {
            _timer?.cancel();
            context.pop();
          },
        ),
      ),
      // ── Wrap entire body in SingleChildScrollView to fix cut-off ──
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
                    widget.taskTitle,
                    textAlign: TextAlign.center,
                    style: AppTypography.screenTitle(color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 20),

                  // ── Project Tag Selector — fixed layout ────────────────
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
                        final isSelected = _selectedProject == tag;
                        return GestureDetector(
                          onTap: () {
                            if (!_isRunning) {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _selectedProject = isSelected ? null : tag;
                              });
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

                  // ── Timer Circle ────────────────────────────────────────
                  GestureDetector(
                    onTap: _toggleTimer,
                    child: AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _isRunning ? _pulseAnimation.value : 1.0,
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
                                    _isRunning
                                        ? AppColors.complete
                                        : AppColors.afternoon,
                                  ),
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _timeString,
                                    style: AppTypography.mono(
                                      size: 58,
                                      weight: FontWeight.w300,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Icon(
                                    _isRunning
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

                  // ── Duration Toggles ────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _DurationToggle(
                        label: '15M',
                        isSelected: _totalSeconds == 15 * 60,
                        onTap: () => _changeDuration(15),
                      ),
                      const SizedBox(width: 12),
                      _DurationToggle(
                        label: '25M',
                        isSelected: _totalSeconds == 25 * 60,
                        onTap: () => _changeDuration(25),
                      ),
                      const SizedBox(width: 12),
                      _DurationToggle(
                        label: '1H',
                        isSelected: _totalSeconds == 60 * 60,
                        onTap: () => _changeDuration(60),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Ambient Sounds ──────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _AmbientToggle(
                        icon: Icons.water_drop,
                        label: 'Rain',
                        isSelected: _currentAmbient == 'rain',
                        onTap: () => _toggleAmbient('rain'),
                      ),
                      const SizedBox(width: 12),
                      _AmbientToggle(
                        icon: Icons.waves,
                        label: 'Noise',
                        isSelected: _currentAmbient == 'noise',
                        onTap: () => _toggleAmbient('noise'),
                      ),
                      const SizedBox(width: 12),
                      _AmbientToggle(
                        icon: Icons.coffee,
                        label: 'Cafe',
                        isSelected: _currentAmbient == 'cafe',
                        onTap: () => _toggleAmbient('cafe'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Reset ───────────────────────────────────────────────
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 12,
                    ),
                    color: AppColors.surfaceRaised,
                    borderRadius: BorderRadius.circular(30),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _timer?.cancel();
                        _isRunning = false;
                        _remainingSeconds = _totalSeconds;
                        _pulseController.stop();
                        _currentAmbient = null;
                        _ambientPlayer.stop();
                      });
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
                  const SizedBox(height: 24),
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
