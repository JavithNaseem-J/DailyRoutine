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

  final List<String> _projectTags = [
    '#Code',
    '#Quran',
    '#Build',
    '#Study',
    '#Work',
    '#Reflect'
  ];

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _ambientPlayer = AudioPlayer();

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

  void _toggleAmbient(String id, String url) async {
    HapticFeedback.lightImpact();
    if (_currentAmbient == id) {
      await _ambientPlayer.pause();
      setState(() => _currentAmbient = null);
    } else {
      setState(() => _currentAmbient = id);
      try {
        await _ambientPlayer.play(UrlSource(url), volume: 0.5);
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
          setState(() {
            _remainingSeconds--;
          });
        } else {
          _timer?.cancel();
          _pulseController.stop();
          setState(() => _isRunning = false);
          HapticFeedback.heavyImpact();
          // Timer finished
          _audioPlayer.play(
            UrlSource(
              'https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3',
            ),
          );
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
    final progress = 1 - (_remainingSeconds / _totalSeconds);

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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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
              const SizedBox(height: 24),
              
              // Project Tag Selector
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  shrinkWrap: true,
                  itemCount: _projectTags.length,
                  separatorBuilder: (context, _) => const SizedBox(width: 8),
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
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isSelected ? AppColors.complete : AppColors.border,
                          ),
                        ),
                        child: Text(
                          tag,
                          style: AppTypography.body(
                            size: 13,
                            weight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 48),

              // Timer Circle
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
                          // Background Ring
                          SizedBox(
                            width: 280,
                            height: 280,
                            child: CircularProgressIndicator(
                              value: 1.0,
                              strokeWidth: 8,
                              valueColor: AlwaysStoppedAnimation(
                                AppColors.surfaceRaised,
                              ),
                            ),
                          ),
                          // Progress Ring
                          SizedBox(
                            width: 280,
                            height: 280,
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 8,
                              strokeCap: StrokeCap.round,
                              valueColor: AlwaysStoppedAnimation(
                                _isRunning
                                    ? AppColors.complete
                                    : AppColors.afternoon,
                              ),
                            ),
                          ),
                          // Time Text
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _timeString,
                                style: AppTypography.mono(
                                  size: 64,
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
                                size: 32,
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 80),

              // Bottom Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _DurationToggle(
                    duration: 15,
                    isSelected: _totalSeconds == 15 * 60,
                    onTap: () => _changeDuration(15),
                  ),
                  const SizedBox(width: 12),
                  _DurationToggle(
                    duration: 25,
                    isSelected: _totalSeconds == 25 * 60,
                    onTap: () => _changeDuration(25),
                  ),
                  const SizedBox(width: 12),
                  _DurationToggle(
                    duration: 60,
                    isSelected: _totalSeconds == 60 * 60,
                    onTap: () => _changeDuration(60),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Ambient Sounds
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _AmbientToggle(
                    icon: Icons.water_drop,
                    label: "Rain",
                    isSelected: _currentAmbient == "rain",
                    onTap: () => _toggleAmbient(
                      "rain",
                      "https://actions.google.com/sounds/v1/water/rain_on_roof.ogg",
                    ),
                  ),
                  const SizedBox(width: 12),
                  _AmbientToggle(
                    icon: Icons.waves,
                    label: "Noise",
                    isSelected: _currentAmbient == "noise",
                    onTap: () => _toggleAmbient(
                      "noise",
                      "https://actions.google.com/sounds/v1/water/waves_crashing_on_rock_beach.ogg",
                    ),
                  ),
                  const SizedBox(width: 12),
                  _AmbientToggle(
                    icon: Icons.coffee,
                    label: "Cafe",
                    isSelected: _currentAmbient == "cafe",
                    onTap: () => _toggleAmbient(
                      "cafe",
                      "https://actions.google.com/sounds/v1/crowds/cafe_restaurant_medium_crowd.ogg",
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
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
            ],
          ),
        ),
      ),
    );
  }
}

class _DurationToggle extends StatelessWidget {
  const _DurationToggle({
    required this.duration,
    required this.isSelected,
    required this.onTap,
  });

  final int duration;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.complete
              : AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '$duration m',
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
