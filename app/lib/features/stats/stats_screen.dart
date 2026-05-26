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
import '../../core/constants/session_data.dart';

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

  int _monthlySkippedCount = 0;
  int _monthlyDelayedCount = 0;
  List<MapEntry<String, int>> _topSkipped = [];
  List<MapEntry<String, int>> _topDelayed = [];

  Map<String, int> _projectMinutesData = {};
  Map<String, int> _prayerCounts = {
    'fajr': 0,
    'dhuhr': 0,
    'asr': 0,
    'maghrib': 0,
    'isha': 0,
  };
  bool _statsLoading = true;
  Map<String, double> _dailyCompletionMap = {};

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
        supabaseService.fetch30DayTaskHistory(deviceId),
      ]);

      if (!mounted) return;

      final streak = results[0] as Streak?;
      final history = results[1] as List<Map<String, dynamic>>;
      final history30 = results[2] as List<Map<String, dynamic>>;
      final taskHistory30 = results[3] as List<Map<String, dynamic>>;

      // Build daily completion map (date → pct) for swipeable weekly chart
      final Map<String, double> dailyMap = {};
      for (final row in history30) {
        try {
          final date = row['date'] as String;
          final pct = (row['completion_pct'] as num? ?? 0).toDouble();
          dailyMap[date] = pct;
        } catch (_) {}
      }

      // Streak reset: find last day in history where completion > 0
      DateTime? lastActiveDay;
      for (final row in history30) {
        try {
          final pct = (row['completion_pct'] as num? ?? 0).toInt();
          if (pct > 0) {
            final dt = DateTime.parse(row['date'] as String);
            if (lastActiveDay == null || dt.isAfter(lastActiveDay)) {
              lastActiveDay = dt;
            }
          }
        } catch (_) {}
      }
      final todayDate = DateTime(today.year, today.month, today.day);
      final gapDays = lastActiveDay == null
          ? 999
          : todayDate
              .difference(DateTime(lastActiveDay.year, lastActiveDay.month, lastActiveDay.day))
              .inDays;
      // If the last completed day is more than 1 day ago, reset streak
      if (gapDays > 1 && (streak?.currentStreak ?? 0) > 0) {
        await streakService.resetStreak();
      }
      final computedStreak = gapDays > 1 ? 0 : (streak?.currentStreak ?? 0);

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

      // Map history list -> Sun-indexed weekly bar data
      final weekly = List<double>.filled(7, 0);
      for (final row in history) {
        try {
          final dt = DateTime.parse(row['date'] as String);
          final dayIdx = dt.weekday == 7 ? 0 : dt.weekday; // Sun=0...Sat=6
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

      // Process taskHistory30 for skipped and delayed tasks
      int monthSkipped = 0;
      int monthDelayed = 0;
      Map<String, int> skippedCounts = {};
      Map<String, int> delayedCounts = {};

      for (final row in taskHistory30) {
        try {
          final dt = DateTime.parse(row['date'] as String);
          if (dt.month == today.month && dt.year == today.year) {
             final statusMap = row['task_status'] as Map<String, dynamic>?;
             if (statusMap != null) {
               statusMap.forEach((taskId, status) {
                 if (status == 'skipped') {
                   monthSkipped++;
                   skippedCounts[taskId] = (skippedCounts[taskId] ?? 0) + 1;
                 } else if (status == 'late') {
                   monthDelayed++;
                   delayedCounts[taskId] = (delayedCounts[taskId] ?? 0) + 1;
                 }
               });
             }
          }
        } catch (_) {}
      }

      final allTasks = <String, String>{};
      for (final s in SessionData.allSessions) {
        for (final t in s.tasks) {
          allTasks[t.id] = t.title;
        }
      }
      for (final t in hiveService.readCustomTasks()) {
        allTasks[t.id] = t.title;
      }

      var sortedSkipped = skippedCounts.entries.toList()..sort((a,b) => b.value.compareTo(a.value));
      var sortedDelayed = delayedCounts.entries.toList()..sort((a,b) => b.value.compareTo(a.value));

      setState(() {
        _weeklyData = weekly;
        _heatmap = heatmap;
        _currentStreak = computedStreak;
        _bestStreak = streak?.bestStreak ?? 0;
        _disciplineHistory = dHistory;
        _currentDisciplineScore = currentDiscipline;
        _monthlySkippedCount = monthSkipped;
        _monthlyDelayedCount = monthDelayed;
        _topSkipped = sortedSkipped.take(3).map((e) => MapEntry(allTasks[e.key] ?? 'Custom Task', e.value)).toList();
        _topDelayed = sortedDelayed.take(3).map((e) => MapEntry(allTasks[e.key] ?? 'Custom Task', e.value)).toList();
        _dailyCompletionMap = dailyMap;
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

    final dayIdx = DateTime.now().weekday == 7 ? 0 : DateTime.now().weekday;
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

    // Live daily map: inject today's live completion so swipeable chart is up-to-date
    final now = DateTime.now();
    final todayKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final liveDailyMap = Map<String, double>.from(_dailyCompletionMap);
    liveDailyMap[todayKey] = completionPct.toDouble();

    // Streak display: always show the current streak (whether today is done or not)
    final displayStreak = _currentStreak;

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
                  margin: const EdgeInsets.only(top: 12, bottom: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.cardSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
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
                                size: 13,
                                color: AppColors.textSecondary,
                                weight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textMuted,
                        size: 20,
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

            _LevelTodayStreakCard(
              score: realScore,
              completionPct: completionPct,
              totalTasks: totalTasks,
              onTimeCount: onTimeCount,
              lateCount: lateCount,
              currentStreak: displayStreak,
              bestStreak: _bestStreak,
              isLoading: _statsLoading,
            ),

            SizedBox(height: 16),

            _PrayerConsistencyCard(prayerCounts: _prayerCounts),

            SizedBox(height: 16),

            _FocusCard(
              totalMinutes: _totalFocusMinutes,
              longestSession: _longestFocusSession,
              totalSessions: _totalFocusSessionsCount,
              projectMinutes: _projectMinutesData,
            ),

            const SizedBox(height: 16),

            _SkippedDelayedCard(
              monthlySkippedCount: _monthlySkippedCount,
              monthlyDelayedCount: _monthlyDelayedCount,
              topSkipped: _topSkipped,
              topDelayed: _topDelayed,
            ),

            const SizedBox(height: 16),

            _SwipeableWeeklyChart(dailyMap: liveDailyMap),

            const SizedBox(height: 16),

            _HeatmapGrid(values: liveHeatmap),

            const SizedBox(height: 32),
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
      decoration: AppColors.cardDecoration(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.mosque_rounded,
                size: 20,
                color: AppColors.primary,
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


// ── Merged: Level · Today · Streak Card ──────────────────────────────────────

class _LevelTodayStreakCard extends StatelessWidget {
  const _LevelTodayStreakCard({
    required this.score,
    required this.completionPct,
    required this.totalTasks,
    required this.onTimeCount,
    required this.lateCount,
    required this.currentStreak,
    required this.bestStreak,
    this.isLoading = false,
  });

  final int score;
  final int completionPct;
  final int totalTasks;
  final int onTimeCount;
  final int lateCount;
  final int currentStreak;
  final int bestStreak;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final level = GamificationService.getProductivityLevel(score);
    final onTimeFraction = totalTasks == 0 ? 0.0 : onTimeCount / totalTasks;
    final lateFraction   = totalTasks == 0 ? 0.0 : lateCount   / totalTasks;

    return Container(
      decoration: AppColors.cardDecoration(),
      child: Column(
        children: [
          // ── Top: Level progress bar ──────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.stars_rounded, color: AppColors.primary, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Level: $level',
                          style: AppTypography.body(
                            size: 14,
                            weight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '$score / 100',
                      style: AppTypography.mono(size: 13, color: AppColors.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: score / 100,
                    minHeight: 10,
                    backgroundColor: AppColors.surfaceRaised,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),

          // ── Divider ──────────────────────────────────────────────
          Divider(height: 1, color: AppColors.border),

          // ── Bottom: Today ring  |  Streak ───────────────────────
          IntrinsicHeight(
            child: Row(
              children: [
                // Today ring
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Today', style: AppTypography.label(color: AppColors.textMuted)),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: 88,
                          height: 88,
                          child: CustomPaint(
                            painter: _RingPainter(
                              onTimeFraction: onTimeFraction,
                              lateFraction:   lateFraction,
                              onTimeColor:    AppColors.complete,
                              lateColor:      Colors.redAccent,
                              trackColor:     AppColors.surfaceRaised,
                              strokeWidth:    9,
                            ),
                            child: Center(
                              child: Text(
                                '$completionPct%',
                                style: AppTypography.mono(
                                  size: 20,
                                  weight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
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
                  ),
                ),

                // Bold vertical divider
                Container(width: 1.5, color: AppColors.border),

                // Streak
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.local_fire_department_rounded,
                                size: 16, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              'STREAK',
                              style: AppTypography.mono(
                                size: 11,
                                weight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isLoading ? '0' : '$currentStreak',
                          style: AppTypography.mono(
                            size: 52,
                            weight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ).copyWith(height: 1),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceRaised,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.emoji_events_rounded,
                                  color: AppColors.primary, size: 13),
                              const SizedBox(width: 4),
                              Text(
                                'Best: $bestStreak',
                                style: AppTypography.body(
                                  size: 11,
                                  weight: FontWeight.w700,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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

    canvas.drawArc(rect, -1.5708, 6.2832, false,
        Paint()
          ..color = trackColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round);

    final totalFraction = onTimeFraction + lateFraction;
    if (totalFraction > 0) {
      canvas.drawArc(rect, -1.5708, 6.2832 * totalFraction, false,
          Paint()
            ..color = lateColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth
            ..strokeCap = StrokeCap.round);

      if (onTimeFraction > 0) {
        canvas.drawArc(rect, -1.5708, 6.2832 * onTimeFraction, false,
            Paint()
              ..color = onTimeColor
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..strokeCap = StrokeCap.round);
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

// Heatmap Grid (monthly calendar view)

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
      final isToday = (i + 1) == today.day;
      final color = _getStageColor(values[i]);
      final isLightBg = values[i] < 34;

      cells.add(
        Tooltip(
          message: 'Day ${i + 1}: ${values[i]}%',
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
              border: isToday
                  ? Border.all(color: AppColors.primary, width: 2.0)
                  : (values[i] == 0 ? Border.all(color: AppColors.border) : null),
            ),
            child: Text(
              '${i + 1}',
              style: AppTypography.mono(
                size: 10,
                weight: isToday ? FontWeight.w900 : FontWeight.w700,
                color: isLightBg ? AppColors.textPrimary : Colors.white,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppColors.cardDecoration(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_month_rounded, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    'HeatMap',
                    style: AppTypography.body(
                      size: 14,
                      weight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Text(
                '${today.year}-${today.month.toString().padLeft(2, '0')}',
                style: AppTypography.label(color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 16),
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
          const SizedBox(height: 8),
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
    required this.projectMinutes,
  });
  final int totalMinutes;
  final int longestSession;
  final int totalSessions;
  final Map<String, int> projectMinutes;

  @override
  Widget build(BuildContext context) {
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;

    // Focus Allocation Logic
    final sortedEntries = projectMinutes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final displayEntries = sortedEntries.take(5).toList();
    final chartTotal = displayEntries.fold<int>(0, (sum, e) => sum + e.value);

    final colors = [
      AppColors.primary,
      AppColors.worship,
      AppColors.midday,
      AppColors.evening,
      AppColors.textMuted,
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppColors.cardDecoration(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.timelapse_rounded,
                  color: AppColors.primary,
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
          const SizedBox(height: 16),
          RichText(
            text: TextSpan(
              style: AppTypography.mono(size: 32, weight: FontWeight.w800, color: AppColors.textPrimary),
              children: [
                TextSpan(text: '$hours'),
                TextSpan(
                  text: ' hr ',
                  style: AppTypography.body(size: 16, weight: FontWeight.w600, color: AppColors.textSecondary),
                ),
                TextSpan(text: '$mins'),
                TextSpan(
                  text: ' min',
                  style: AppTypography.body(size: 16, weight: FontWeight.w600, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (chartTotal > 0) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 12,
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
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: List.generate(displayEntries.length, (i) {
                final entry = displayEntries[i];
                final entryKey = entry.key;
                final pct = (entry.value / chartTotal * 100).toStringAsFixed(1);

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors[i % colors.length],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$entryKey ($pct%)',
                      style: AppTypography.body(
                        size: 12,
                        weight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                );
              }),
            ),
            const SizedBox(height: 24),
          ],
          
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
      decoration: AppColors.cardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.shield_outlined, color: AppColors.primary, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Discipline Score',
                    style: AppTypography.body(
                      size: 13,
                      weight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                score.toString(),
                style: AppTypography.mono(
                  size: 52,
                  weight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ).copyWith(letterSpacing: -2, height: 1),
              ),
              Text(
                '/100',
                style: AppTypography.body(
                  size: 13,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: SizedBox(
              height: 64,
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
                      barWidth: 2.5,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        checkToShowDot: (spot, barData) =>
                            spot.x == (history.length - 1).toDouble(),
                        getDotPainter: (spot, pct, bar, idx) =>
                            FlDotCirclePainter(
                          radius: 4,
                          color: AppColors.primary,
                          strokeWidth: 0,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.primary.withValues(alpha: 0.15),
                            AppColors.primary.withValues(alpha: 0.0),
                          ],
                        ),
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
    );
  }
}


class _SkippedDelayedCard extends StatelessWidget {
  const _SkippedDelayedCard({
    required this.monthlySkippedCount,
    required this.monthlyDelayedCount,
    required this.topSkipped,
    required this.topDelayed,
  });

  final int monthlySkippedCount;
  final int monthlyDelayedCount;
  final List<MapEntry<String, int>> topSkipped;
  final List<MapEntry<String, int>> topDelayed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppColors.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Discipline Gaps',
                style: AppTypography.body(size: 14, weight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'This Month',
                  style: AppTypography.body(size: 11, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildStatColumn('Skipped', monthlySkippedCount, topSkipped, AppColors.moodLow, Icons.remove_circle_outline_rounded)),
              const SizedBox(width: 12),
              Container(width: 1, height: 100, color: AppColors.border),
              const SizedBox(width: 12),
              Expanded(child: _buildStatColumn('Delayed', monthlyDelayedCount, topDelayed, AppColors.afternoon, Icons.watch_later_outlined)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String title, int count, List<MapEntry<String, int>> top, Color color, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(title, style: AppTypography.body(size: 13, weight: FontWeight.w600, color: AppColors.textPrimary)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count',
                style: AppTypography.mono(size: 12, weight: FontWeight.w700, color: color),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (top.isEmpty)
          Text('None yet! 🎉', style: AppTypography.body(size: 12, color: AppColors.textMuted))
        else
          ...top.asMap().entries.map((entry) {
            final rank = entry.key + 1;
            final e = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceRaised,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$rank',
                      style: AppTypography.mono(size: 9, weight: FontWeight.w700, color: AppColors.textMuted),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      e.key,
                      style: AppTypography.body(size: 12, color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '×${e.value}',
                    style: AppTypography.mono(size: 11, weight: FontWeight.w700, color: color),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

class _SwipeableWeeklyChart extends StatefulWidget {
  const _SwipeableWeeklyChart({required this.dailyMap});
  final Map<String, double> dailyMap;

  @override
  State<_SwipeableWeeklyChart> createState() => _SwipeableWeeklyChartState();
}

class _SwipeableWeeklyChartState extends State<_SwipeableWeeklyChart> {
  final _controller = PageController();
  int _currentPage = 0;
  static const _totalWeeks = 4;

  // Returns the Sunday that starts the week 'weeksBack' weeks ago
  DateTime _weekStart(int weeksBack) {
    final today = DateTime.now();
    // weekday: Mon=1..Sun=7 → days since Sunday: weekday % 7
    final daysSinceSunday = today.weekday % 7;
    final thisSunday = DateTime(today.year, today.month, today.day)
        .subtract(Duration(days: daysSinceSunday));
    return thisSunday.subtract(Duration(days: weeksBack * 7));
  }

  String _weekLabel(int weeksBack) {
    if (weeksBack == 0) return 'This Week';
    if (weeksBack == 1) return 'Last Week';
    return '$weeksBack Weeks Ago';
  }

  List<double> _getWeekData(int weeksBack) {
    final start = _weekStart(weeksBack);
    return List.generate(7, (i) {
      final day = start.add(Duration(days: i));
      final key =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      return widget.dailyMap[key] ?? 0.0;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const days = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    final today = DateTime.now();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppColors.cardDecoration(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.complete,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Completion %',
                    style: AppTypography.body(size: 11, color: AppColors.textMuted),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _currentPage < _totalWeeks - 1
                        ? () => _controller.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            )
                        : null,
                    child: Icon(
                      Icons.chevron_left_rounded,
                      size: 20,
                      color: _currentPage < _totalWeeks - 1
                          ? AppColors.textSecondary
                          : AppColors.textMuted.withValues(alpha: 0.3),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _weekLabel(_currentPage),
                    style: AppTypography.label(color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: _currentPage > 0
                        ? () => _controller.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            )
                        : null,
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: _currentPage > 0
                          ? AppColors.textSecondary
                          : AppColors.textMuted.withValues(alpha: 0.3),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: PageView.builder(
              controller: _controller,
              onPageChanged: (page) => setState(() => _currentPage = page),
              itemCount: _totalWeeks,
              itemBuilder: (context, pageIndex) {
                final data = _getWeekData(pageIndex);
                final weekStart = _weekStart(pageIndex);
                return BarChart(
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
                            if (i < 0 || i >= days.length) {
                              return const SizedBox();
                            }
                            final dayDate = weekStart.add(Duration(days: i));
                            final isToday = dayDate.year == today.year &&
                                dayDate.month == today.month &&
                                dayDate.day == today.day;
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                days[i],
                                style: AppTypography.mono(
                                  size: 10,
                                  color: isToday
                                      ? AppColors.textPrimary
                                      : AppColors.textMuted,
                                  weight: isToday
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
                      final dayDate = weekStart.add(Duration(days: i));
                      final isToday = dayDate.year == today.year &&
                          dayDate.month == today.month &&
                          dayDate.day == today.day;
                      return BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: data[i],
                            width: 20,
                            borderRadius: BorderRadius.circular(10),
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
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}



