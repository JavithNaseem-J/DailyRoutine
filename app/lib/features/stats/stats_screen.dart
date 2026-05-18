import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/streak_service.dart';
import '../../core/models/streak.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../main.dart' show deviceId;
import '../sessions/providers/sessions_provider.dart';
import '../../core/services/hive_service.dart';
import '../../core/services/gamification_service.dart';

Color _getStageColor(int pct) {
  if (pct >= 100) return AppColors.complete;
  if (pct >= 67) return AppColors.complete.withValues(alpha: 0.75);
  if (pct >= 34) return AppColors.complete.withValues(alpha: 0.50);
  if (pct > 0) return AppColors.complete.withValues(alpha: 0.25);
  return AppColors.surfaceRaised;
}

// Stats Screen

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  List<int> _heatmap = List.filled(
    DateTime(DateTime.now().year, DateTime.now().month + 1, 0).day,
    0,
  );

  List<double> _weeklyData = List.filled(7, 0);
  List<double> _disciplineHistory = List.filled(7, 0);
  int _currentDisciplineScore = 0;

  int _currentStreak = 0;
  int _bestStreak = 0;
  int _totalFocusMinutes = 0;
  int _longestFocusSession = 0;
  int _totalFocusSessionsCount = 0;
  Map<String, int> _projectMinutesData = {};
  Map<String, int> _prayerCounts = {
    'fajr': 0,
    'dhuhr': 0,
    'asr': 0,
    'maghrib': 0,
    'isha': 0,
  };
  bool _statsLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRealData();
  }

  Future<void> _loadRealData() async {
    try {
      // 1. Load local data FIRST so the UI updates immediately
      final localStates = hiveService.readAllDailyStates();
      final today = DateTime.now();
      int focusMin = 0;
      int maxSession = 0;
      int totalSessions = 0;
      Map<String, int> tagMins = {};
      Map<String, int> pCounts = {
        'fajr': 0,
        'dhuhr': 0,
        'asr': 0,
        'maghrib': 0,
        'isha': 0,
      };

      for (final s in localStates) {
        try {
          final dt = DateTime.parse(s.date);
          if (dt.month == today.month && dt.year == today.year) {
            focusMin += s.focusMinutes;
            if (s.focusSessions.isNotEmpty) {
              totalSessions += s.focusSessions.length;
              final maxInDay = s.focusSessions.reduce((a, b) => a > b ? a : b);
              if (maxInDay > maxSession) maxSession = maxInDay;
            }
            s.projectMinutes.forEach((k, v) {
              tagMins[k] = (tagMins[k] ?? 0) + v;
            });

            s.prayerStates.forEach((k, v) {
              if (v == true) {
                pCounts[k] = (pCounts[k] ?? 0) + 1;
              }
            });
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _totalFocusMinutes = focusMin;
          _longestFocusSession = maxSession;
          _totalFocusSessionsCount = totalSessions;
          _projectMinutesData = tagMins;
          _prayerCounts = pCounts;
        });
      }

      // 2. Fetch network data in parallel
      final results = await Future.wait([
        streakService.fetchStreak(),
        supabaseService.fetchStatsHistory(7, deviceId),
        supabaseService.fetchStatsHistory(30, deviceId),
      ]);

      if (!mounted) return;

      final streak = results[0] as Streak?;
      final history = results[1] as List<Map<String, dynamic>>;
      final history30 = results[2] as List<Map<String, dynamic>>;

      // Discipline Score calculation
      final localStatesEnd = hiveService.readAllDailyStates();
      List<double> dHistory = List.filled(7, 0);
      int currentDiscipline = 0;
      for (final s in localStatesEnd) {
        try {
          final dt = DateTime.parse(s.date);
          final diff = DateTime(
            today.year,
            today.month,
            today.day,
          ).difference(DateTime(dt.year, dt.month, dt.day)).inDays;
          if (diff >= 0 && diff < 7) {
            int tTasks = s.taskStatus.isNotEmpty
                ? s.taskStatus.length
                : 5; // fallback to 5
            // for today, the build method will override it with actual totalTasks from sessionsProvider
            int score = GamificationService.calculateDisciplineScore(
              s,
              currentStreak: streak?.currentStreak ?? 0,
              totalScheduledTasks: tTasks,
            );
            dHistory[6 - diff] = score.toDouble();
            if (diff == 0) currentDiscipline = score;
          }
        } catch (_) {}
      }

      // Map history list -> Mon-indexed weekly bar data
      final weekly = List<double>.filled(7, 0);
      for (final row in history) {
        try {
          final dt = DateTime.parse(row['date'] as String);
          final dayIdx = dt.weekday - 1; // Mon=0...Sun=6
          if (dayIdx >= 0 && dayIdx < 7) {
            weekly[dayIdx] = (row['completion_pct'] as num).toDouble();
          }
        } catch (_) {}
      }

      // Map history to current month calendar
      final daysInMonth = DateTime(today.year, today.month + 1, 0).day;
      final heatmap = List<int>.filled(daysInMonth, 0);

      for (int i = 0; i < history30.length; i++) {
        try {
          final row = history30[i];
          final dt = DateTime.parse(row['date'] as String);
          if (dt.month == today.month && dt.year == today.year) {
            final pct = (row['completion_pct'] as num).toInt();
            heatmap[dt.day - 1] = pct;
          }
        } catch (_) {}
      }

      setState(() {
        _weeklyData = weekly;
        _heatmap = heatmap;
        _currentStreak = streak?.currentStreak ?? 0;
        _bestStreak = streak?.bestStreak ?? 0;
        _disciplineHistory = dHistory;
        _currentDisciplineScore = currentDiscipline;
      });
    } catch (_) {
      // Network or unexpected error
    } finally {
      // NEW-BUG-005 fix: always stop spinner, even on error
      if (mounted) setState(() => _statsLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(sessionsProvider);
    final completionPct = ref.watch(completionPctProvider);
    final sessionsList = sessionsAsync.value?.sessions ?? [];
    int totalTasks = 0;
    for (var s in sessionsList) {
      totalTasks += s.tasks.where((t) => !t.isBreak).length;
    }

    final dayIdx = DateTime.now().weekday - 1;
    final liveHeatmap = List<int>.from(_heatmap);
    final liveWeekly = List<double>.from(_weeklyData);
    final liveDisciplineHistory = List<double>.from(_disciplineHistory);
    int realScore = _currentDisciplineScore;

    if (!_statsLoading) {
      // Re-calculate today's using dynamic totalTasks
      final todayStr =
          "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}";
      final todayState = hiveService.readDailyState(todayStr);
      realScore = GamificationService.calculateDisciplineScore(
        todayState,
        currentStreak: _currentStreak,
        totalScheduledTasks: totalTasks,
      );
      if (liveDisciplineHistory.isNotEmpty) {
        liveDisciplineHistory[6] = realScore.toDouble();
      }

      if (liveHeatmap.isNotEmpty) {
        final todayIdx = DateTime.now().day - 1;
        if (todayIdx < liveHeatmap.length) {
          liveHeatmap[todayIdx] = completionPct;
        }
      }
      if (liveWeekly.isNotEmpty && dayIdx >= 0 && dayIdx < 7) {
        liveWeekly[dayIdx] = completionPct.toDouble();
      }
    }

    int onTimeCount = 0;
    int lateCount = 0;
    final todayStrTemp =
        "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}";
    final todayStateTemp = hiveService.readDailyState(todayStrTemp);

    todayStateTemp.taskStatus.forEach((_, status) {
      if (status == 'on_time') {
        onTimeCount++;
      } else if (status == 'late') {
        lateCount++;
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
          children: [
            SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Stats',
                  style: AppTypography.screenTitle(
                    color: AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.settings_outlined,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () => context.push('/settings'),
                ),
              ],
            ),

            Builder(
              builder: (context) {
                final level = GamificationService.getProductivityLevel(realScore);
                String insight;

                if (realScore >= 91) {
                  insight = 'Elite performance! 🏆 Score: $realScore/100. You\'re in peak discipline mode.';
                } else if (_currentStreak > 2 && realScore >= 76) {
                  insight = 'Disciplined & consistent! 🔥 $_currentStreak-day streak + score $realScore/100.';
                } else if (completionPct > 80 && realScore >= 51) {
                  insight = 'Focused level reached! Great task completion ($completionPct%) today.';
                } else if (_totalFocusSessionsCount > 1) {
                  insight = '$_totalFocusSessionsCount deep-work sessions logged. Longest: ${_longestFocusSession}m. Keep it up!';
                } else if (_totalFocusMinutes > 30) {
                  insight = '$_totalFocusMinutes min of focus this month. Level: $level — keep building momentum.';
                } else if (_currentStreak > 0) {
                  insight = '$_currentStreak-day streak active. Score: $realScore/100. Don\'t break the chain!';
                } else {
                  insight = 'Level: $level. Score $realScore/100 — consistency is the foundation of excellence.';
                }

                return Container(
                  margin: const EdgeInsets.only(top: 20, bottom: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Daily Insight',
                              style: AppTypography.body(
                                size: 12,
                                weight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              insight,
                              style: AppTypography.body(
                                size: 14,
                                color: AppColors.textPrimary,
                                weight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            _DisciplineScoreCard(
              score: realScore,
              history: liveDisciplineHistory,
            ),
            const SizedBox(height: 16),
            _ProductivityLevelMeter(score: realScore),
            const SizedBox(height: 16),

            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _CompletionRingCard(
                      completionPct: completionPct,
                      totalTasks: totalTasks,
                      onTimeCount: onTimeCount,
                      lateCount: lateCount,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StreakCard(
                      currentStreak: _currentStreak,
                      bestStreak: _bestStreak,
                      isLoading: _statsLoading,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 16),

            _PrayerConsistencyCard(prayerCounts: _prayerCounts),

            SizedBox(height: 16),

            _FocusCard(
              totalMinutes: _totalFocusMinutes,
              longestSession: _longestFocusSession,
              totalSessions: _totalFocusSessionsCount,
            ),

            const SizedBox(
              height: 16,
            ), // Ã¢â€â‚¬Ã¢â€â‚¬ Weekly progress bar chart Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
            _WeeklyChart(data: liveWeekly),

            SizedBox(height: 16),

            _FocusAllocationCard(
              projectMinutes: _projectMinutesData,
              totalMinutes: _totalFocusMinutes,
            ),

            SizedBox(height: 16),

            _HeatmapGrid(values: liveHeatmap),

            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// Prayer Consistency Card

class _PrayerConsistencyCard extends StatelessWidget {
  const _PrayerConsistencyCard({required this.prayerCounts});
  final Map<String, int> prayerCounts;

  @override
  Widget build(BuildContext context) {
    const prayers = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];
    const labels = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.mosque_rounded,
                size: 20,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                'Prayer',
                style: AppTypography.body(
                  size: 14,
                  weight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(5, (i) {
              final count = prayerCounts[prayers[i]] ?? 0;
              final intensity =
                  (DateTime.now().day > 0 ? count / DateTime.now().day : 0.0)
                      .clamp(0.0, 1.0);
              final pct = (intensity * 100).round();
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: CustomPaint(
                      painter: _GradientArcPainter(
                        fraction: intensity,
                        strokeWidth: 4,
                      ),
                      child: Center(
                        child: Text(
                          '$pct%',
                          style: AppTypography.mono(
                            size: 10,
                            weight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    labels[i],
                    style: AppTypography.mono(
                      size: 11,
                      weight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

// Completion Ring Card

class _CompletionRingCard extends StatelessWidget {
  const _CompletionRingCard({
    required this.completionPct,
    required this.totalTasks,
    required this.onTimeCount,
    required this.lateCount,
  });

  final int completionPct;
  final int totalTasks;
  final int onTimeCount;
  final int lateCount;

  @override
  Widget build(BuildContext context) {
    final onTimeFraction = totalTasks == 0 ? 0.0 : onTimeCount / totalTasks;
    final lateFraction = totalTasks == 0 ? 0.0 : lateCount / totalTasks;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text('Today', style: AppTypography.label(color: AppColors.textMuted)),
          SizedBox(height: 12),
          SizedBox(
            width: 90,
            height: 90,
            child: CustomPaint(
              painter: _RingPainter(
                onTimeFraction: onTimeFraction,
                lateFraction: lateFraction,
                onTimeColor: AppColors.complete,
                lateColor: Colors.redAccent,
                trackColor: AppColors.surfaceRaised,
                strokeWidth: 8,
              ),
              child: Center(
                child: Text(
                  '$completionPct%',
                  style: AppTypography.ringPercent(
                    color: AppColors.textPrimary,
                  ).copyWith(fontSize: 18),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '$totalTasks tasks today',
            style: AppTypography.label(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.onTimeFraction,
    required this.lateFraction,
    required this.onTimeColor,
    required this.lateColor,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double onTimeFraction;
  final double lateFraction;
  final Color onTimeColor;
  final Color lateColor;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);

    // Track (background circle)
    canvas.drawArc(
      rect,
      -1.5708, // -pi/2
      6.2832,
      false,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    final totalFraction = onTimeFraction + lateFraction;
    if (totalFraction > 0) {
      canvas.drawArc(
        rect,
        -1.5708,
        6.2832 * totalFraction,
        false,
        Paint()
          ..color = lateColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );

      if (onTimeFraction > 0) {
        canvas.drawArc(
          rect,
          -1.5708,
          6.2832 * onTimeFraction,
          false,
          Paint()
            ..color = onTimeColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.onTimeFraction != onTimeFraction ||
      old.lateFraction != lateFraction ||
      old.onTimeColor != onTimeColor ||
      old.lateColor != lateColor;
}

// Streak Card

class _StreakCard extends StatelessWidget {
  const _StreakCard({
    required this.currentStreak,
    required this.bestStreak,
    this.isLoading = false,
  });

  final int currentStreak;
  final int bestStreak;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.complete.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.whatshot_rounded,
                  size: 16,
                  color: AppColors.complete,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'STREAK',
                style: AppTypography.mono(
                  size: 11,
                  weight: FontWeight.w800,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),

          Text(
            isLoading ? '0' : '$currentStreak',
            style: AppTypography.mono(
              size: 48,
              weight: FontWeight.w900,
              color: AppColors.textPrimary,
            ).copyWith(letterSpacing: -2, height: 1.1),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.complete.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.complete.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.emoji_events_rounded,
                  color: AppColors.complete,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  'Best: $bestStreak',
                  style: AppTypography.body(
                    size: 11,
                    weight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Weekly Bar Chart

class _WeeklyChart extends StatelessWidget {
  const _WeeklyChart({required this.data});

  final List<double> data;

  @override
  Widget build(BuildContext context) {
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final todayIndex = DateTime.now().weekday - 1; // Mon=0

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Weekly Progress',
                style: AppTypography.body(
                  size: 14,
                  weight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.complete,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Completion %',
                    style: AppTypography.label(color: AppColors.textMuted),
                  ),
                ],
              ),
            ],
          ),

          SizedBox(height: 16),

          // Bar chart
          SizedBox(
            height: 120,
            child: BarChart(
              BarChartData(
                maxY: 100,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= days.length) return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            days[i],
                            style: AppTypography.mono(
                              size: 10,
                              color: i == todayIndex
                                  ? AppColors.textPrimary
                                  : AppColors.textMuted,
                              weight: i == todayIndex
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(data.length, (i) {
                  final isToday = i == todayIndex;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: data[i],
                        width: 20,
                        borderRadius: BorderRadius.circular(6),
                        color: isToday
                            ? AppColors.complete
                            : AppColors.complete.withValues(alpha: 0.35),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: 100,
                          color: AppColors.surfaceRaised,
                        ),
                      ),
                    ],
                  );
                }),
              ),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOut,
            ),
          ),
        ],
      ),
    );
  }
}

// Heatmap Grid  (30 days view)

class _HeatmapGrid extends StatelessWidget {
  const _HeatmapGrid({required this.values});

  final List<int> values;

  @override
  Widget build(BuildContext context) {
    final DateTime today = DateTime.now();
    final int daysInMonth = DateTime(today.year, today.month + 1, 0).day;
    final DateTime startDate = DateTime(today.year, today.month, 1);
    final int startWeekday = startDate.weekday - 1; // 0=Mon, 6=Sun

    final List<Widget> cells = [];
    for (int i = 0; i < startWeekday; i++) {
      cells.add(const SizedBox()); // empty padding
    }

    for (int i = 0; i < daysInMonth && i < values.length; i++) {
      final color = _getStageColor(values[i]);
      // NEW-BUG-009 fix: consistent with _getStageColor thresholds (0-33% = light bg)
      final isLightBg = values[i] < 34;

      cells.add(
        Tooltip(
          message: 'Day ${i + 1}',
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
              border: values[i] == 0
                  ? Border.all(color: AppColors.border)
                  : null,
            ),
            child: Text(
              '${i + 1}',
              style: AppTypography.mono(
                size: 10,
                weight: FontWeight.w700,
                color: isLightBg ? AppColors.textMuted : Colors.white,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'HeatMap',
                style: AppTypography.body(
                  size: 14,
                  weight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '${today.year}-${today.month.toString().padLeft(2, '0')}',
                style: AppTypography.label(color: AppColors.textSecondary),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                .map(
                  (l) => SizedBox(
                    width: 20,
                    child: Text(
                      l,
                      textAlign: TextAlign.center,
                      style: AppTypography.mono(
                        size: 10,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 7,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: cells,
          ),
        ],
      ),
    );
  }
}

// Focus Card

class _FocusCard extends StatelessWidget {
  const _FocusCard({
    required this.totalMinutes,
    required this.longestSession,
    required this.totalSessions,
  });
  final int totalMinutes;
  final int longestSession;
  final int totalSessions;

  @override
  Widget build(BuildContext context) {
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.complete.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.timelapse_rounded,
                  color: AppColors.complete,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Total Focus Time',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontFamily: 'SF Pro Display',
                color: AppColors.textPrimary,
              ),
              children: [
                TextSpan(
                  text: '$hours',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
                TextSpan(
                  text: ' hr ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                TextSpan(
                  text: '$mins',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
                TextSpan(
                  text: ' min',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniStat('Longest Session', '${longestSession}m'),
              _buildMiniStat('Total Sessions', '$totalSessions'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.body(size: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTypography.sectionTitle(color: AppColors.textPrimary),
        ),
      ],
    );
  }
}

// Focus Allocation Card

class _FocusAllocationCard extends StatelessWidget {
  const _FocusAllocationCard({
    required this.projectMinutes,
    required this.totalMinutes,
  });

  final Map<String, int> projectMinutes;
  final int totalMinutes;

  @override
  Widget build(BuildContext context) {
    if (projectMinutes.isEmpty) return const SizedBox.shrink();

    // Sort by descending minutes
    final sortedEntries = projectMinutes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Limit to top 5 projects
    final displayEntries = sortedEntries.take(5).toList();
    final chartTotal = displayEntries.fold<int>(0, (sum, e) => sum + e.value);

    // Assign specific colors to common tags or cycle colors
    final colors = [
      AppColors.primary,
      AppColors.worship,
      AppColors.midday,
      AppColors.evening,
      AppColors.textMuted,
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Focus Allocation',
            style: AppTypography.screenTitle(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Based on logged tag time',
            style: AppTypography.body(size: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),

          // Horizontal Stacked Bar Chart
          if (chartTotal > 0)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 16,
                child: Row(
                  children: List.generate(displayEntries.length, (i) {
                    final isEnd = i == displayEntries.length - 1;
                    return Expanded(
                      flex: displayEntries[i].value,
                      child: Container(
                        margin: EdgeInsets.only(right: isEnd ? 0 : 2),
                        color: colors[i % colors.length],
                      ),
                    );
                  }),
                ),
              ),
            ),
          const SizedBox(height: 20),

          // Legend
          if (chartTotal > 0)
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: List.generate(displayEntries.length, (i) {
                final entry = displayEntries[i];
                final entryKey = entry.key;
                final pct = (entry.value / chartTotal * 100).toStringAsFixed(1);

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors[i % colors.length],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$entryKey ($pct%)',
                      style: AppTypography.body(
                        size: 13,
                        weight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                );
              }),
            ),
        ],
      ),
    );
  }
}

class _GradientArcPainter extends CustomPainter {
  const _GradientArcPainter({
    required this.fraction,
    required this.strokeWidth,
  });

  final double fraction;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Track
    final trackPaint = Paint()
      ..color = AppColors.surfaceRaised
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    if (fraction <= 0) return;

    // Gradient Arc
    final arcPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.complete, AppColors.complete.withValues(alpha: 0.6)],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708, // -pi/2
      6.2832 * fraction,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_GradientArcPainter old) => old.fraction != fraction;
}

class _DisciplineScoreCard extends StatelessWidget {
  const _DisciplineScoreCard({required this.score, required this.history});
  final int score;
  final List<double> history;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Discipline Score',
                style: AppTypography.sectionTitle(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                score.toString(),
                style: AppTypography.screenTitle(
                  color: AppColors.textPrimary,
                ).copyWith(fontSize: 48),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(show: false),
                      titlesData: FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: history
                              .asMap()
                              .entries
                              .map((e) => FlSpot(e.key.toDouble(), e.value))
                              .toList(),
                          isCurved: true,
                          color: AppColors.primary,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: AppColors.primary.withValues(alpha: 0.1),
                          ),
                        ),
                      ],
                      minY: 0,
                      maxY: 100,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProductivityLevelMeter extends StatelessWidget {
  const _ProductivityLevelMeter({required this.score});
  final int score;

  @override
  Widget build(BuildContext context) {
    final level = GamificationService.getProductivityLevel(score);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.stars_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Level: $level',
                    style: AppTypography.sectionTitle(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Text(
                '$score / 100',
                style: AppTypography.body(color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: 12,
              backgroundColor: AppColors.surfaceRaised,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
