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

// ─────────────────────────────────────────────────────────────────────────────
// Stats Screen
// ─────────────────────────────────────────────────────────────────────────────

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  List<int> _heatmap = List.filled(28, 0);
  int _chartRange = 0;

  // Real data loaded async
  List<double> _weeklyData = List.filled(7, 0);
  int _currentStreak = 0;
  int _bestStreak = 0;
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
    // 3. Build heatmap from 28-day history
    final history28 = await supabaseService.fetchStatsHistory(28, deviceId);

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

    // Map 28-day history → heatmap (0=none,1=partial,2=complete)
    final heatmap = List<int>.filled(28, 0);
    for (int i = 0; i < history28.length && i < 28; i++) {
      try {
        final pct = (history28[history28.length - 1 - i]['completion_pct'] as num).toInt();
        heatmap[27 - i] = pct >= 100 ? 2 : pct > 0 ? 1 : 0;
      } catch (_) {}
    }

    setState(() {
      _weeklyData = weekly;
      _heatmap = heatmap;
      _currentStreak = streak?.currentStreak ?? 0;
      _bestStreak = streak?.bestStreak ?? 0;
      _statsLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(sessionsProvider);
    final completionPct = ref.watch(completionPctProvider);
    final mood = sessionsAsync.value?.dailyState.mood;
    final totalTasks = SessionData.taskIdsForToday(
      isFriday: DayChecker.isFriday(),
      isSunday: DayChecker.isSunday(),
    ).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            const SizedBox(height: 16),

            // ── Header ──────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Statistics',
                    style: AppTypography.screenTitle(
                        color: AppColors.textPrimary)),
                IconButton(
                  icon: const Icon(Icons.settings_outlined,
                      color: AppColors.textSecondary),
                  onPressed: () => context.push('/settings'),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Completion ring + streak side by side ────────────────
            Row(
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

            const SizedBox(height: 16),

            // ── Mood selector ──────────────────────────────────────────
            _MoodSelector(
              selected: mood,
              onSelect: (m) => ref.read(sessionsProvider.notifier).setMood(m),
            ),

            const SizedBox(height: 16),

            // ── Weekly progress bar chart ────────────────────────────
            _WeeklyChart(
              data: _weeklyData,
              rangeIndex: _chartRange,
              onRangeChanged: (i) => setState(() => _chartRange = i),
            ),

            const SizedBox(height: 16),

            // ── Habit performance list ───────────────────────────────
            _HabitPerformanceCard(
              taskStates: sessionsAsync.value?.dailyState.taskStates ?? {},
              isFriday: DayChecker.isFriday(),
              isSunday: DayChecker.isSunday(),
            ),

            const SizedBox(height: 16),

            // ── Heatmap grid ─────────────────────────────────────────
            _HeatmapGrid(
              values: _heatmap,
              onTap: (i) async {
                final newVal = (_heatmap[i] + 1) % 3;
                setState(() {
                  _heatmap = List.from(_heatmap)..[i] = newVal;
                });
                // Compute date for cell i (today = cell 27)
                final cellDate = DateTime.now()
                    .subtract(Duration(days: 27 - i));
                final dateKey = dateService.keyFor(cellDate);
                supabaseService
                    .upsertHeatmap(dateKey, newVal, deviceId)
                    .catchError((_) {});
              },
            ),

            const SizedBox(height: 32),
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
          Text('Today',
              style: AppTypography.label(color: AppColors.textMuted)),
          const SizedBox(height: 12),
          SizedBox(
            width: 100,
            height: 100,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: completionPct / 100),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOut,
              builder: (context, value, _) => CustomPaint(
                painter: _RingPainter(
                  fraction: value,
                  ringColor: AppColors.complete,
                  trackColor: AppColors.surfaceRaised,
                  strokeWidth: 10,
                ),
                child: Center(
                  child: Text(
                    '$completionPct%',
                    style: AppTypography.ringPercent(
                        color: AppColors.textPrimary),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text('$totalTasks tasks today',
              style: AppTypography.label(color: AppColors.textMuted)),
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
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text('Streak',
              style: AppTypography.label(color: Colors.white60)),
          const SizedBox(height: 8),
          Text(
            isLoading ? '–' : '$currentStreak',
            style: AppTypography.streakNumber(color: Colors.white),
          ),
          Text('days',
              style: AppTypography.label(color: Colors.white60)),
          const SizedBox(height: 12),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 10),
          Text('Best',
              style: AppTypography.label(color: Colors.white60)),
          Text(
            isLoading ? '–' : '$bestStreak',
            style: AppTypography.mono(
                size: 16, weight: FontWeight.w700, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mood Selector
// ─────────────────────────────────────────────────────────────────────────────

class _MoodSelector extends StatelessWidget {
  const _MoodSelector({required this.selected, required this.onSelect});

  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    const moods = [
      (key: 'low', emoji: '😔', label: 'Low'),
      (key: 'mid', emoji: '😐', label: 'Okay'),
      (key: 'high', emoji: '😊', label: 'Great'),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Text("Today's Mood",
              style: AppTypography.body(
                  size: 13,
                  weight: FontWeight.w500,
                  color: AppColors.textPrimary)),
          const Spacer(),
          Row(
            children: moods.map((m) {
              final isSelected = selected == m.key;
              return GestureDetector(
                onTap: () => onSelect(m.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.border,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    m.emoji,
                    style: TextStyle(fontSize: isSelected ? 20 : 18),
                  ),
                ),
              );
            }).toList(),
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
              Text('Weekly Progress',
                  style: AppTypography.body(
                      size: 14,
                      weight: FontWeight.w600,
                      color: AppColors.textPrimary)),
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
                          horizontal: 10, vertical: 4),
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

          const SizedBox(height: 16),

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
    required this.taskStates,
    required this.isFriday,
    required this.isSunday,
  });

  final Map<String, bool> taskStates;
  final bool isFriday;
  final bool isSunday;

  @override
  Widget build(BuildContext context) {
    final todaySessions = SessionData.sessionsForToday(
      isFriday: isFriday,
      isSunday: isSunday,
    );

    // Compute today's per-session completion %
    final sessions = todaySessions.map((s) {
      final total = s.tasks.length;
      final done = total == 0
          ? 0
          : s.tasks.where((t) => taskStates[t.id] == true).length;
      final pct = total == 0 ? 0 : (done * 100) ~/ total;
      return (name: s.name, pct: pct, color: s.accentColor);
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
          Text('Habit Performance',
              style: AppTypography.body(
                  size: 14,
                  weight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text('Last 30 days',
              style: AppTypography.label(color: AppColors.textMuted)),
          const SizedBox(height: 14),
          ...sessions.map((s) => Padding(
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
                      child: Text(s.name,
                          style: AppTypography.body(
                              size: 13, color: AppColors.textPrimary)),
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
                            color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Heatmap Grid  (4 rows × 7 cols = 28 days)
// ─────────────────────────────────────────────────────────────────────────────

class _HeatmapGrid extends StatelessWidget {
  const _HeatmapGrid({required this.values, required this.onTap});

  final List<int> values;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    const cellColors = [
      AppColors.surfaceRaised, // 0 = none
      Color(0xFFBBF7D0), // 1 = partial (light green)
      AppColors.complete, // 2 = complete
    ];

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
              Text('28-Day Heatmap',
                  style: AppTypography.body(
                      size: 14,
                      weight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              Row(
                children: [
                  _HeatmapLegend(color: AppColors.surfaceRaised, label: 'None'),
                  const SizedBox(width: 8),
                  _HeatmapLegend(color: const Color(0xFFBBF7D0), label: 'Partial'),
                  const SizedBox(width: 8),
                  _HeatmapLegend(color: AppColors.complete, label: 'Done'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
            ),
            itemCount: 28,
            itemBuilder: (_, i) {
              return GestureDetector(
                onTap: () => onTap(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: cellColors[values[i]],
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HeatmapLegend extends StatelessWidget {
  const _HeatmapLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
        ),
        const SizedBox(width: 3),
        Text(label,
            style: AppTypography.label(color: AppColors.textMuted)),
      ],
    );
  }
}
