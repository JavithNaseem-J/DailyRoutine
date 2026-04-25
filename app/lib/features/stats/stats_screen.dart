import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/session_data.dart';
import '../../core/services/streak_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/date_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/day_checker.dart';
import '../../main.dart' show deviceId;
import '../sessions/providers/sessions_provider.dart';
import '../../core/services/hive_service.dart';

Color _getStageColor(int pct) {
  if (pct >= 100) return AppColors.complete;
  if (pct >= 67) return AppColors.complete.withValues(alpha: 0.75);
  if (pct >= 34) return AppColors.complete.withValues(alpha: 0.50);
  if (pct > 0) return AppColors.complete.withValues(alpha: 0.25);
  return AppColors.surfaceRaised;
}

// ─────────────────────────────────────────────────────────────────────────────
// Stats Screen
// ─────────────────────────────────────────────────────────────────────────────

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  List<int> _heatmap = List.filled(DateTime(DateTime.now().year, DateTime.now().month + 1, 0).day, 0);
  int _chartRange = 0;

  List<double> _weeklyData = List.filled(7, 0);
  List<Map<String, dynamic>> _taskHistory = [];
  int _currentStreak = 0;
  int _bestStreak = 0;
  int _totalFocusMinutes = 0;
  Map<String, int> _projectMinutesData = {};
  Map<String, int> _prayerCounts = {'fajr': 0, 'dhuhr': 0, 'asr': 0, 'maghrib': 0, 'isha': 0};
  bool _statsLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRealData();
  }

  Future<void> _loadRealData() async {
    // 1. Fetch streak
    final streak = await streakService.fetchStreak();
    // 2. Fetch 7-day stats history for bar chart
    final history = await supabaseService.fetchStatsHistory(7, deviceId);
    // 3. Build heatmap from 30-day history
    final history30 = await supabaseService.fetchStatsHistory(30, deviceId);
    // 4. Fetch real task history for performance calculations
    final taskHistory = await supabaseService.fetch30DayTaskHistory(deviceId);

    if (!mounted) return;

    // Map history list → Mon-indexed weekly bar data
    final weekly = List<double>.filled(7, 0);
    for (final row in history) {
      try {
        final dt = DateTime.parse(row['date'] as String);
        final dayIdx = dt.weekday - 1; // Mon=0…Sun=6
        if (dayIdx >= 0 && dayIdx < 7) {
          weekly[dayIdx] = (row['completion_pct'] as num).toDouble();
        }
      } catch (_) {}
    }

    // Map history to current month calendar
    final today = DateTime.now();
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

    final localStates = hiveService.readAllDailyStates();
    int focusMin = 0;
    Map<String, int> tagMins = {};
    Map<String, int> pCounts = {'fajr': 0, 'dhuhr': 0, 'asr': 0, 'maghrib': 0, 'isha': 0};

    for (final s in localStates) {
      try {
        final dt = DateTime.parse(s.date);
        if (dt.month == today.month && dt.year == today.year) {
          focusMin += s.focusMinutes;
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

    setState(() {
      _weeklyData = weekly;
      _heatmap = heatmap;
      _taskHistory = taskHistory;
      _currentStreak = streak?.currentStreak ?? 0;
      _bestStreak = streak?.bestStreak ?? 0;
      _totalFocusMinutes = focusMin;
      _projectMinutesData = tagMins;
      _prayerCounts = pCounts;
      _statsLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(sessionsProvider);
    final completionPct = ref.watch(completionPctProvider);
    final sessionsList = sessionsAsync.value?.sessions ?? [];
    int totalTasks = 0;
    for (var s in sessionsList) {
      totalTasks += s.tasks.length;
    }

    final dayIdx = DateTime.now().weekday - 1;
    final liveHeatmap = List<int>.from(_heatmap);
    final liveWeekly = List<double>.from(_weeklyData);
    if (!_statsLoading) {
      if (liveHeatmap.isNotEmpty) {
        int todayIdx = DateTime.now().day - 1;
        if (todayIdx < liveHeatmap.length) liveHeatmap[todayIdx] = completionPct;
      }
      if (liveWeekly.isNotEmpty && dayIdx >= 0 && dayIdx < 7) {
        liveWeekly[dayIdx] = completionPct.toDouble();
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            SizedBox(height: 16),

            // ── Header ──────────────────────────────────────────────
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

            SizedBox(height: 16),
            if (!_statsLoading && _taskHistory.isNotEmpty)
              _InsightsBadge(history: _taskHistory),
            if (!_statsLoading && _taskHistory.isNotEmpty)
              SizedBox(height: 16),

            // ── Completion ring + streak side by side ────────────────
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _CompletionRingCard(
                      completionPct: completionPct,
                      totalTasks: totalTasks,
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

            // ── Prayer Consistency ──────────────────────────────────
            _PrayerConsistencyCard(prayerCounts: _prayerCounts),

            SizedBox(height: 16),

            // ── Complete Hours in Focus Card ────────────────────────
            _FocusCard(totalMinutes: _totalFocusMinutes),

            const SizedBox(
              height: 16,
            ), // ── Weekly progress bar chart ────────────────────────────
            _WeeklyChart(
              data: liveWeekly,
            ),

            SizedBox(height: 16),

            // ── Focus Allocation ─────────────────────────────────────
            _FocusAllocationCard(
              projectMinutes: _projectMinutesData,
              totalMinutes: _totalFocusMinutes,
            ),

            SizedBox(height: 16),

            // ── Heatmap grid ─────────────────────────────────────────
            _HeatmapGrid(
              values: liveHeatmap,
            ),

            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Prayer Consistency Card
// ─────────────────────────────────────────────────────────────────────────────

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
              Icon(Icons.self_improvement_rounded, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(
                'Salah Performance',
                style: AppTypography.body(size: 14, weight: FontWeight.w600, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(5, (i) {
               final count = prayerCounts[prayers[i]] ?? 0;
               final intensity = (count / DateTime.now().day).clamp(0.0, 1.0);
               final pct = (intensity * 100).round();
               return Column(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   Container(
                     width: 36,
                     height: 36,
                     decoration: BoxDecoration(
                       shape: BoxShape.circle,
                       color: intensity == 0 
                          ? AppColors.surfaceRaised 
                          : AppColors.complete.withValues(alpha: 0.2 + (0.8 * intensity)),
                     ),
                     child: Center(
                       child: Text(
                         '$pct%',
                         style: AppTypography.mono(
                           size: 10,
                           weight: FontWeight.w700,
                           color: intensity == 0 ? AppColors.textMuted : (intensity > 0.5 ? Colors.white : AppColors.complete),
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
          )
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Completion Ring Card
// ─────────────────────────────────────────────────────────────────────────────

class _CompletionRingCard extends StatelessWidget {
  const _CompletionRingCard({
    required this.completionPct,
    required this.totalTasks,
  });

  final int completionPct;
  final int totalTasks;

  @override
  Widget build(BuildContext context) {
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
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: completionPct / 100),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOut,
              builder: (context, value, _) => CustomPaint(
                painter: _RingPainter(
                  fraction: value,
                  ringColor: AppColors.complete,
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
          ),
          SizedBox(height: 10),
          Text(
            '$totalTasks tasks today',
            style: AppTypography.label(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ring Painter (shared by completion + streak)
// ─────────────────────────────────────────────────────────────────────────────

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.fraction,
    required this.ringColor,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double fraction;
  final Color ringColor;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);

    // Track
    canvas.drawArc(
      rect,
      -1.5708, // -π/2 (top)
      6.2832, // full circle
      false,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    // Fill arc
    if (fraction > 0) {
      canvas.drawArc(
        rect,
        -1.5708,
        6.2832 * fraction,
        false,
        Paint()
          ..color = ringColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.ringColor != ringColor;
}

// ─────────────────────────────────────────────────────────────────────────────
// Streak Card
// ─────────────────────────────────────────────────────────────────────────────

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
            isLoading ? '–' : '$currentStreak',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 48,
              fontWeight: FontWeight.w900,
              letterSpacing: -2,
              color: AppColors.textPrimary,
              height: 1.1,
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.complete.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.complete.withValues(alpha: 0.3)),
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

// ─────────────────────────────────────────────────────────────────────────────
// Weekly Bar Chart
// ─────────────────────────────────────────────────────────────────────────────

class _WeeklyChart extends StatelessWidget {
  const _WeeklyChart({
    required this.data,
  });

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



// ─────────────────────────────────────────────────────────────────────────────
// Heatmap Grid  (30 days view)
// ─────────────────────────────────────────────────────────────────────────────

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
      final isLightBg = values[i] <= 2;
      
      cells.add(
        Tooltip(
          message: 'Day ${i + 1}',
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
              border: values[i] == 0 ? Border.all(color: AppColors.border) : null,
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

// ─────────────────────────────────────────────────────────────────────────────
// Insights Badge
// ─────────────────────────────────────────────────────────────────────────────

class _InsightsBadge extends StatelessWidget {
  const _InsightsBadge({required this.history});
  final List<Map<String, dynamic>> history;

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) return const SizedBox();

    String insight = "🔥 You're building solid momentum!";
    final map = <int, int>{};
    for (final row in history) {
      final dt = DateTime.parse(row['date'] as String);
      final states = row['task_states'] as Map<String, dynamic>? ?? {};
      int done = states.values.where((v) => v == true).length;
      map[dt.weekday] = (map[dt.weekday] ?? 0) + done;
    }
    if (map.isNotEmpty) {
      final best = map.entries.reduce((a, b) => a.value > b.value ? a : b);
      final days = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      insight = "💡 Your most productive day is ${days[best.key - 1]}.";
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.tipBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            color: AppColors.primary,
            size: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              insight,
              style: AppTypography.body(
                size: 13,
                weight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Focus Card
// ─────────────────────────────────────────────────────────────────────────────

class _FocusCard extends StatelessWidget {
  const _FocusCard({required this.totalMinutes});
  final int totalMinutes;

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
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Focus Allocation Card
// ─────────────────────────────────────────────────────────────────────────────

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

