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
  if (pct >= 67) return Color(0xFF3B82F6);
  if (pct >= 34) return Color(0xFF93C5FD);
  if (pct > 0) return Color(0xFFDBEAFE);
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
    for (final s in localStates) {
      focusMin += s.focusMinutes;
      s.projectMinutes.forEach((k, v) {
        tagMins[k] = (tagMins[k] ?? 0) + v;
      });
    }

    setState(() {
      _weeklyData = weekly;
      _heatmap = heatmap;
      _taskHistory = taskHistory;
      _currentStreak = streak?.currentStreak ?? 0;
      _bestStreak = streak?.bestStreak ?? 0;
      _totalFocusMinutes = focusMin;
      _projectMinutesData = tagMins;
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
                    flex: 3,
                    child: _CompletionRingCard(
                      completionPct: completionPct,
                      totalTasks: totalTasks,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
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

            // ── Complete Hours in Focus Card ────────────────────────
            _FocusCard(totalMinutes: _totalFocusMinutes),

            const SizedBox(
              height: 16,
            ), // ── Weekly progress bar chart ────────────────────────────
            _WeeklyChart(
              data: liveWeekly,
              rangeIndex: _chartRange,
              onRangeChanged: (i) => setState(() => _chartRange = i),
            ),

            SizedBox(height: 16),

            // ── Habit performance list ───────────────────────────────
            _HabitPerformanceCard(
              history: _taskHistory,
              isFriday: DayChecker.isFriday(),
              isSunday: DayChecker.isSunday(),
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
              onTap: (i) async {
                int newVal = 0;
                if (_heatmap[i] == 0) {
                  newVal = 33;
                } else if (_heatmap[i] < 67) {
                  newVal = 67;
                } else if (_heatmap[i] < 100) {
                  newVal = 100;
                } else {
                  newVal = 0;
                }

                setState(() {
                  _heatmap = List.from(_heatmap)..[i] = newVal;
                });
                // Compute date for cell i (day i+1 of current month)
                final today = DateTime.now();
                final cellDate = DateTime(today.year, today.month, i + 1);
                final dateKey = dateService.keyFor(cellDate);
                supabaseService
                    .upsertHeatmap(dateKey, newVal, deviceId)
                    .catchError((_) {});
              },
            ),

            SizedBox(height: 32),
          ],
        ),
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
            width: 70,
            height: 70,
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
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.whatshot_rounded,
                  size: 16,
                  color: AppColors.primary,
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
              color: AppColors.primary,
              height: 1.1,
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.emoji_events_rounded,
                  color: AppColors.afternoon,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  'Best: $bestStreak',
                  style: AppTypography.body(
                    size: 11,
                    weight: FontWeight.w600,
                    color: AppColors.textPrimary,
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
    required this.rangeIndex,
    required this.onRangeChanged,
  });

  final List<double> data;
  final int rangeIndex;
  final ValueChanged<int> onRangeChanged;

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
              // Range toggle
              Row(
                children: List.generate(3, (i) {
                  const labels = ['W', 'M', 'Y'];
                  final active = i == rangeIndex;
                  return GestureDetector(
                    onTap: () => onRangeChanged(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: active ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: active ? AppColors.primary : AppColors.border,
                        ),
                      ),
                      child: Text(
                        labels[i],
                        style: AppTypography.mono(
                          size: 11,
                          weight: FontWeight.w600,
                          color: active ? Colors.white : AppColors.textMuted,
                        ),
                      ),
                    ),
                  );
                }),
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
// Habit Performance Card
// ─────────────────────────────────────────────────────────────────────────────

class _HabitPerformanceCard extends StatelessWidget {
  const _HabitPerformanceCard({
    required this.history,
    required this.isFriday,
    required this.isSunday,
  });

  final List<Map<String, dynamic>> history;
  final bool isFriday;
  final bool isSunday;

  @override
  Widget build(BuildContext context) {
    final todaySessions = SessionData.sessionsForToday(
      isFriday: isFriday,
      isSunday: isSunday,
    );

    final taskCompleteCount = <String, int>{};
    for (final row in history) {
      final states = row['task_states'] as Map<String, dynamic>? ?? {};
      for (final entry in states.entries) {
        if (entry.value == true) {
          taskCompleteCount[entry.key] =
              (taskCompleteCount[entry.key] ?? 0) + 1;
        }
      }
    }

    final totalDays = history.isEmpty ? 1 : history.length;

    final sessions = todaySessions.map((s) {
      if (s.tasks.isEmpty) {
        return (name: s.name, pct: 0, color: _getStageColor(0));
      }

      int done = 0;
      for (var t in s.tasks) {
        done += taskCompleteCount[t.id] ?? 0;
      }
      final potential = s.tasks.length * totalDays;
      final pct = (done * 100) ~/ potential;

      return (name: s.name, pct: pct, color: _getStageColor(pct));
    }).toList();

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
                'Habit Performance',
                style: AppTypography.body(
                  size: 14,
                  weight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                'Last 30 Days',
                style: AppTypography.label(color: AppColors.textSecondary),
              ),
            ],
          ),
          SizedBox(height: 16),
          ...sessions.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  // Accent dot
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: s.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      s.name,
                      style: AppTypography.body(
                        size: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  // Mini bar
                  SizedBox(
                    width: 80,
                    child: Stack(
                      children: [
                        Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceRaised,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: s.pct / 100,
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: s.color,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 34,
                    child: Text(
                      '${s.pct}%',
                      textAlign: TextAlign.right,
                      style: AppTypography.mono(
                        size: 11,
                        weight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
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

String _formatMonth(int month) {
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  return months[month - 1];
}

class _HeatmapGrid extends StatelessWidget {
  const _HeatmapGrid({required this.values, required this.onTap});

  final List<int> values;
  final ValueChanged<int> onTap;

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
        GestureDetector(
          onTap: () => onTap(i),
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
                '${_formatMonth(today.month)} ${today.year}',
                style: AppTypography.label(color: AppColors.textSecondary),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                .map(
                  (l) => SizedBox(
                    width: 30,
                    child: Text(
                      l,
                      textAlign: TextAlign.center,
                      style: AppTypography.mono(
                        size: 10,
                        color: AppColors.textMuted,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 7,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
            childAspectRatio: 1,
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
        color: AppColors.completeFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.complete.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            color: AppColors.complete,
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
                  color: AppColors.primary.withValues(alpha: 0.1),
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
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                    color: AppColors.primary,
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
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                    color: AppColors.primary,
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

