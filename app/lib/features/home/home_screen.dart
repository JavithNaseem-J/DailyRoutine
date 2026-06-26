import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:confetti/confetti.dart';
import 'package:uuid/uuid.dart';

import '../../core/models/prayer_times.dart';
import '../../core/models/quick_task.dart';
import '../../core/services/date_service.dart';
import '../../core/services/hive_service.dart';
import '../../core/services/prayer_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/quote_service.dart';
import '../../core/services/weather_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../sessions/providers/sessions_provider.dart';
import '../../main.dart' show deviceId, sharedPrefs;
import '../../core/services/connectivity_service.dart';
import 'widgets/schedule_sheet.dart';

// Home Screen

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late Timer _prayerTimer;
  late ({String name, DateTime adhaan, DateTime prayerStart}) _prayerData;
  late PrayerTimes _todayPrayers;
  late List<({int dateNum, String abbr, bool isToday, DateTime date})>
  _weekStrip;
  late final ConfettiController _confettiController;

  // Planned Events mapped by date string
  Map<String, String> _plannedEvents = {};


  // Task Board
  List<QuickTask> _quickTasks = [];

  WeatherData? _weatherData;
  QuoteData? _dailyQuote;
  bool _isOnline = true;
  StreamSubscription<bool>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    _isOnline = connectivityService.isConnected;
    _connectivitySub = connectivityService.onConnectivityChanged.listen((connected) {
      if (mounted) setState(() => _isOnline = connected);
    });
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );
    _weekStrip = dateService.buildWeekStripWithDates();
    _todayPrayers = prayerService.getTodayPrayerTimes();
    _prayerData = prayerService.getPrayerData(DateTime.now());
    _loadPlannedEvents();
    _loadQuickTasks();
    _loadWeather();
    _loadQuote();

    _prayerTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(
          () => _prayerData = prayerService.getPrayerData(DateTime.now()),
        );
      }
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _confettiController.dispose();
    _prayerTimer.cancel();
    super.dispose();
  }

  Future<void> _loadWeather() async {
    final w = await weatherService.getWeatherData();
    if (mounted) setState(() => _weatherData = w);
  }

  Future<void> _loadQuote() async {
    final q = await quoteService.getDailyQuote();
    if (mounted) setState(() => _dailyQuote = q);
  }

  // Week Planner
  void _loadPlannedEvents() {
    final map = <String, String>{};
    for (final d in _weekStrip) {
      final dateKey = dateService.keyFor(d.date);
      final newKey = 'schedule_$dateKey';
      final oldKey = 'event_$dateKey';
      
      final newVal = sharedPrefs.getString(newKey);
      final oldVal = sharedPrefs.getString(oldKey);
      
      if ((newVal != null && newVal != '[]') || (oldVal != null && oldVal.isNotEmpty)) {
        map[dateKey] = 'has_events';
      }
    }
    setState(() => _plannedEvents = map);
  }




  void _loadQuickTasks() {
    setState(() {
      _quickTasks = _deduplicateTasks(hiveService.readQuickTasks('global'));
    });
    supabaseService.fetchQuickTasks('global', deviceId).catchError((_) => <QuickTask>[]).then((remote) { // NEW-BUG-008 fix
      if (!mounted) return;
      if (remote.isEmpty && _quickTasks.isNotEmpty) {
        // Fix: Avoid wiping local data if remote fetch fails or is empty due to RLS.
        for (final t in _quickTasks) {
          supabaseService.upsertQuickTask(t, deviceId).catchError((_) {});
        }
        return;
      }
      final cleaned = _deduplicateTasks(remote);
      setState(() => _quickTasks = cleaned);
      hiveService.writeQuickTasks('global', cleaned);
      // Write back to Supabase too if we removed ghosts
      if (cleaned.length != remote.length) {
        for (final ghost in remote.where((r) => cleaned.every((c) => c.id != r.id))) {
          supabaseService.deleteQuickTask(ghost.id).catchError((_) {});
        }
      }
    });
  }

  /// Removes duplicate tasks created by the old buggy _add() that generated
  /// two QuickTask objects with different UUIDs for the same user input.
  /// Dedup key = title (case-insensitive) + isUrgent + isImportant.
  List<QuickTask> _deduplicateTasks(List<QuickTask> tasks) {
    final seen = <String>{};
    final result = <QuickTask>[];
    for (final t in tasks) {
      final key = '${t.title.trim().toLowerCase()}|${t.isUrgent}|${t.isImportant}';
      if (seen.add(key)) result.add(t);
    }
    return result;
  }

  QuickTask _addQuickTask(String title, bool isUrgent, bool isImportant) {
    final task = QuickTask(
      isUrgent: isUrgent,
      isImportant: isImportant,
      id: const Uuid().v4(),
      date: 'global',
      title: title,
    );
    setState(() {
      _quickTasks = [..._quickTasks, task];
    });
    hiveService.writeQuickTasks('global', _quickTasks);
    supabaseService.upsertQuickTask(task, deviceId).catchError((_) {});
    return task;
  }

  void _toggleQuickTask(String id) {
    final i = _quickTasks.indexWhere((t) => t.id == id);
    if (i < 0) return;
    final updated = _quickTasks[i].copyWith(done: !_quickTasks[i].done);
    setState(() => _quickTasks = [..._quickTasks]..[i] = updated);
    hiveService.writeQuickTasks('global', _quickTasks);
    supabaseService.upsertQuickTask(updated, deviceId).catchError((_) {});
  }

  void _deleteQuickTask(String id) {
    final i = _quickTasks.indexWhere((t) => t.id == id);
    if (i < 0) return;
    final task = _quickTasks[i];
    setState(() => _quickTasks = [..._quickTasks]..removeAt(i));
    hiveService.writeQuickTasks('global', _quickTasks);
    supabaseService.deleteQuickTask(task.id).catchError((_) {});
  }

  void _updateQuickTask(QuickTask updated) {
    final i = _quickTasks.indexWhere((t) => t.id == updated.id);
    if (i < 0) return;
    setState(() => _quickTasks = [..._quickTasks]..[i] = updated);
    hiveService.writeQuickTasks('global', _quickTasks);
    supabaseService.upsertQuickTask(updated, deviceId).catchError((_) {});
  }



  ({String text, IconData icon}) _greetingData(int hour) {
    if (hour >= 4 && hour < 6) {
      return (text: 'As-salamu alaykum', icon: Icons.nightlight_round);
    }
    if (hour >= 6 && hour < 9) {
      return (text: 'Good Morning', icon: Icons.wb_twilight_rounded);
    }
    if (hour >= 9 && hour < 12) {
      return (text: 'Good Morning', icon: Icons.wb_sunny_rounded);
    }
    if (hour >= 12 && hour < 15) {
      return (text: 'Good Afternoon', icon: Icons.light_mode_outlined);
    }
    if (hour >= 15 && hour < 18) {
      return (text: 'Good Afternoon', icon: Icons.wb_sunny_outlined);
    }
    if (hour >= 18 && hour < 21) {
      return (text: 'Good Evening', icon: Icons.cloud_outlined);
    }
    return (text: 'Good Night', icon: Icons.nights_stay_outlined);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(completionPctProvider, (previous, next) {
      if (previous != null && previous != 100 && next == 100) {
        _confettiController.play();
        HapticFeedback.heavyImpact();
      }
    });

    final now = DateTime.now();
    final greeting = _greetingData(now.hour);
    final displayGreeting = greeting.text;

    Widget buildHeader() {
      if (_weatherData != null) {
        final w = _weatherData!;
        IconData weatherIcon = Icons.cloud;
        final c = w.condition.toLowerCase();
        final hour = DateTime.now().hour;
        final isNight = hour >= 18 || hour < 6;
        if (c.contains('clear')) {
          weatherIcon = isNight ? Icons.nights_stay : Icons.wb_sunny;
        } else if (c.contains('rain') || c.contains('drizzle')) {
          weatherIcon = Icons.water_drop;
        } else if (c.contains('thunder')) {
          weatherIcon = Icons.bolt;
        } else if (c.contains('snow')) {
          weatherIcon = Icons.ac_unit;
        }

        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Stack(
            children: [
              // Background Watermarks (Stars, Thunder, Rain, Clouds)
              // Cloud 1
              Positioned(
                left: -10,
                top: 15,
                child: Transform.rotate(
                  angle: -0.15,
                  child: Icon(
                    Icons.cloud_outlined,
                    size: 40,
                    color: AppColors.textSecondary.withValues(alpha: 0.15),
                  ),
                ),
              ),
              // Cloud 2
              Positioned(
                right: 90,
                top: -10,
                child: Transform.rotate(
                  angle: 0.1,
                  child: Icon(
                    Icons.cloud,
                    size: 32,
                    color: AppColors.textSecondary.withValues(alpha: 0.15),
                  ),
                ),
              ),
              // Star 1
              Positioned(
                right: 25,
                top: 5,
                child: Icon(
                  Icons.star_rounded,
                  size: 26,
                  color: AppColors.textSecondary.withValues(alpha: 0.15),
                ),
              ),
              // Star 2
              Positioned(
                right: 130,
                bottom: 8,
                child: Icon(
                  Icons.star_outline_rounded,
                  size: 16,
                  color: AppColors.textSecondary.withValues(alpha: 0.15),
                ),
              ),
              // Thunder
              Positioned(
                right: -5,
                bottom: -5,
                child: Transform.rotate(
                  angle: 0.25,
                  child: Icon(
                    Icons.bolt_rounded,
                    size: 42,
                    color: AppColors.textSecondary.withValues(alpha: 0.15),
                  ),
                ),
              ),
              // Rain 1
              Positioned(
                left: 75,
                top: -8,
                child: Transform.rotate(
                  angle: -0.2,
                  child: Icon(
                    Icons.water_drop_outlined,
                    size: 28,
                    color: AppColors.textSecondary.withValues(alpha: 0.15),
                  ),
                ),
              ),
              // Rain 2
              Positioned(
                left: 150,
                bottom: -10,
                child: Icon(
                  Icons.water_drop_rounded,
                  size: 20,
                  color: AppColors.textSecondary.withValues(alpha: 0.15),
                ),
              ),
              // Main Content
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(weatherIcon, size: 28, color: AppColors.textPrimary),
                    const SizedBox(width: 12),
                    Text(
                      '${w.temp}°',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isNight && c.contains('clear') ? 'Clear skies tonight' : w.condition,
                            style: AppTypography.body(size: 14, weight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Feels like ${w.feelsLike}°  •  Humidity ${w.humidity}%',
                            style: AppTypography.body(size: 12, color: AppColors.textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      } else {
        return Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                greeting.icon,
                color: AppColors.textPrimary,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                displayGreeting,
                style: AppTypography.screenTitle(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        );
      }
    }

    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(bottom: false, child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
              children: [
                SizedBox(height: 16),
                if (!_isOnline)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDF2F2),
                      border: Border.all(color: const Color(0xFFFDE8E8)),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.cloud_off_rounded,
                          color: Color(0xFFE02424),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Offline Mode. Content will sync to cloud when you reconnect.',
                            style: AppTypography.body(
                              size: 13,
                              weight: FontWeight.w600,
                              color: const Color(0xFF9B1C1C),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                buildHeader(),

                SizedBox(height: 16),

                _WeekStrip(
                  days: _weekStrip,
                  plannedEvents: _plannedEvents,
                  onDateTap: (date) async {
                    await ScheduleSheet.show(context, date);
                    _loadPlannedEvents();
                  },
                  onDateLongPress: (date) async {
                    await ScheduleSheet.show(context, date);
                    _loadPlannedEvents();
                  },
                ),

                SizedBox(height: 20),

                if (_dailyQuote != null)
                  _QuoteCard(text: _dailyQuote!.text, author: _dailyQuote!.author)
                else
                  const SizedBox(),

                SizedBox(height: 16),

                _PrayerCard(prayer: _prayerData, todayPrayers: _todayPrayers),
                const SizedBox(height: 24),

                const _JobApplicationsCard(),
                const SizedBox(height: 24),

                _TaskBoard(
                  tasks: _quickTasks,
                  onAdd: _addQuickTask,
                  onDelete: _deleteQuickTask,
                  onToggle: _toggleQuickTask,
                  onUpdate: _updateQuickTask,
                  onRefresh: _loadQuickTasks,
                ),



                SizedBox(height: 32),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            emissionFrequency: 0.05,
            numberOfParticles: 20,
            maxBlastForce: 20,
            minBlastForce: 8,
            gravity: 0.3,
            colors: [
              AppColors.complete,
              Colors.blue,
              Colors.orange,
              Colors.purple,
              Colors.pink,
            ],
          ),
        ),
      ],
    );
  }
}


// Week Strip

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.days,
    required this.plannedEvents,
    required this.onDateTap,
    required this.onDateLongPress,
  });
  final List<({int dateNum, String abbr, bool isToday, DateTime date})> days;
  final Map<String, String> plannedEvents;
  final Function(DateTime) onDateTap;
  final Function(DateTime) onDateLongPress;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: days.map((d) {
          final hasEvent = plannedEvents.containsKey(dateService.keyFor(d.date));
          return Padding(
            padding: const EdgeInsets.only(right: 20.0),
            child: GestureDetector(
              onTap: () => onDateTap(d.date),
              onLongPress: () => onDateLongPress(d.date),
              behavior: HitTestBehavior.opaque,
              child: Column(
            children: [
              Text(
                d.abbr,
                style: AppTypography.label(
                  color: d.isToday
                      ? AppColors.textPrimary
                      : AppColors.dayInactiveTxt,
                ),
              ),
              SizedBox(height: 4),
              Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: d.isToday
                          ? AppColors.dayActive
                          : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${d.dateNum}',
                        style: AppTypography.body(
                          size: 13,
                          weight: d.isToday ? FontWeight.w700 : FontWeight.w400,
                          color: d.isToday
                              ? AppColors.dayActiveTxt
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  if (hasEvent)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Color(0xFFEF4444), // Red dot
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    }).toList(),
  ),
);
  }
}

// Quote Card

class _QuoteCard extends StatefulWidget {
  const _QuoteCard({required this.text, required this.author});
  final String text;
  final String author;

  @override
  State<_QuoteCard> createState() => _QuoteCardState();
}

class _QuoteCardState extends State<_QuoteCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
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
            Row(
              children: [
                Icon(Icons.auto_awesome, size: 14, color: AppColors.textPrimary),
                const SizedBox(width: 8),
                Text(
                  'QUOTE OF THE DAY',
                  style: AppTypography.body(
                    color: AppColors.textPrimary,
                    size: 12,
                    weight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Icon(
                  _expanded ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                  color: AppColors.textPrimary,
                ),
              ],
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          top: -20,
                          left: -10,
                          child: Text(
                            '"',
                            style: TextStyle(
                              fontFamily: 'serif',
                              fontSize: 80,
                              color: AppColors.textSecondary.withValues(alpha: 0.15),
                              height: 1.0,
                            ),
                          ),
                        ),
                        Text(
                          widget.text,
                          textAlign: TextAlign.left,
                          style: AppTypography.body(
                            size: 14,
                            color: AppColors.textPrimary,
                            height: 1.5,
                            weight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      height: 1,
                      width: double.infinity,
                      color: AppColors.border.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '- ${widget.author}',
                          style: AppTypography.mono(
                            size: 11,
                            color: AppColors.textSecondary,
                            weight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 300),
              sizeCurve: Curves.easeInOut,
            ),
          ],
        ),
      ),
    );
  }
}


class _PrayerCard extends ConsumerWidget {
  const _PrayerCard({required this.prayer, required this.todayPrayers});
  final ({String name, DateTime adhaan, DateTime prayerStart}) prayer;
  final PrayerTimes todayPrayers;

  String _fmt(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _fmtShort(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prayerList = todayPrayers.asOrderedList();
    final now = DateTime.now();
    final prayerStates = ref.watch(sessionsProvider).value?.dailyState.prayerStates ?? {};

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF232526), Color(0xFF111111)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF111111).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -30,
            child: Icon(
              Icons.mosque_rounded,
              size: 160,
              color: Colors.white.withValues(alpha: 0.15),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          Column(
            children: [
              // Top aligned row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    prayer.name,
                    style: AppTypography.body(
                      size: 46,
                      weight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.0,
                    ),
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.volume_up_rounded, size: 9, color: Colors.white38),
                          const SizedBox(width: 4),
                          Text('Adhaan', style: AppTypography.label(color: Colors.white38)),
                        ],
                      ),
                      Text(
                        _fmt(prayer.adhaan),
                        style: AppTypography.mono(size: 13, weight: FontWeight.w700, color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
              // Bottom aligned row
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Builder(
                    builder: (context) {
                      final now = DateTime.now();
                      final remaining = now.isBefore(prayer.adhaan)
                          ? prayer.adhaan.difference(now)
                          : prayer.prayerStart.difference(now);
                      if (remaining.isNegative) {
                        return const SizedBox.shrink();
                      }
                      final hours = remaining.inHours;
                      final mins = remaining.inMinutes.remainder(60);
                      final rStr = hours > 0
                          ? '${hours}h ${mins}m left'
                          : '${mins}m left';
                      return Row(
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            color: Colors.white54,
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            rStr,
                            style: AppTypography.mono(
                              size: 13,
                              weight: FontWeight.w700,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.mosque_rounded, size: 10, color: AppColors.complete),
                          const SizedBox(width: 4),
                          Text('Prayer', style: AppTypography.label(color: AppColors.complete)),
                        ],
                      ),
                      Text(
                        _fmt(prayer.prayerStart),
                        style: AppTypography.mono(size: 13, weight: FontWeight.w700, color: AppColors.complete),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          SizedBox(height: 10),
          Divider(color: Colors.white12, height: 1),
          SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: prayerList.map((p) {
              final isPast = p.time.isBefore(now);
              return Column(
                children: [
                  Text(
                    p.name[0].toUpperCase() + p.name.substring(1),
                    style: AppTypography.label(
                      color: !isPast
                          ? AppColors.complete
                          : Colors.white24,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    _fmtShort(p.time),
                    style: AppTypography.mono(
                      size: 10,
                      weight: !isPast ? FontWeight.w700 : FontWeight.w400,
                      color: !isPast
                          ? Colors.white
                          : Colors.white24,
                    ),
                  ),
                  SizedBox(height: 4),
                  GestureDetector(
                    onTap: () {
                      ref.read(sessionsProvider.notifier).togglePrayer(p.name);
                    },
                    child: Container(
                      width: 28, // MULTIPLIED
                      height: 28, // MULTIPLIED
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: (prayerStates[p.name.toLowerCase()] == true)
                              ? AppColors.complete
                              : Colors.white24,
                          width: 2,
                        ),
                        color: (prayerStates[p.name.toLowerCase()] == true)
                            ? AppColors.complete.withValues(alpha: 0.2)
                            : Colors.transparent,
                      ),
                      child: (prayerStates[p.name.toLowerCase()] == true)
                          ? Icon(Icons.check, size: 20, color: AppColors.complete) // MULTIPLIED
                          : null,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
          ),
        ],
      ),
    );
  }
}


class _JobApplicationsCard extends ConsumerWidget {
  const _JobApplicationsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionsProvider);
    final count = sessionsAsync.value?.dailyState.jobApplicationsCount ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left side Info
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryFaint,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.work_outline_rounded,
                    color: AppColors.textPrimary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Job Hunt',
                    style: AppTypography.body(
                      size: 15,
                      weight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Right side Controls
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Minus Button
              _ActionButton(
                icon: Icons.remove,
                onPressed: count > 0
                    ? () {
                        HapticFeedback.lightImpact();
                        ref
                            .read(sessionsProvider.notifier)
                            .updateJobApplicationsCount(count - 1);
                      }
                    : null,
              ),
              const SizedBox(width: 8),
              // Counter Display
              SizedBox(
                width: 32,
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, animation) {
                      return ScaleTransition(scale: animation, child: child);
                    },
                    child: Text(
                      '$count',
                      key: ValueKey(count),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Plus Button
              _ActionButton(
                icon: Icons.add,
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  ref
                      .read(sessionsProvider.notifier)
                      .updateJobApplicationsCount(count + 1);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.onPressed});
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: enabled ? AppColors.primary : AppColors.surfaceRaised,
          shape: BoxShape.circle,
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          size: 16,
          color: enabled ? Colors.white : AppColors.textMuted,
        ),
      ),
    );
  }
}


const _kQuadrants = [
  (label: 'Do it',       urgency: true,  important: true,  hex: 0xFF10B981, icon: Icons.bolt_rounded),
  (label: 'Schedule it', urgency: false, important: true,  hex: 0xFFF59E0B, icon: Icons.calendar_month_rounded),
  (label: 'Delegate it', urgency: true,  important: false, hex: 0xFF3B82F6, icon: Icons.group_add_rounded),
  (label: 'Skip it',   urgency: false, important: false, hex: 0xFFEF4444, icon: Icons.delete_outline_rounded),
];

class _TaskBoard extends StatefulWidget {
  const _TaskBoard({
    required this.tasks,
    required this.onAdd,
    required this.onDelete,
    required this.onToggle,
    required this.onUpdate,
    this.onRefresh,
  });

  final List<QuickTask> tasks;
  final QuickTask Function(String title, bool isUrgent, bool isImportant) onAdd;
  final ValueChanged<String> onDelete;
  final ValueChanged<String> onToggle;
  final ValueChanged<QuickTask> onUpdate;
  final VoidCallback? onRefresh;

  @override
  State<_TaskBoard> createState() => _TaskBoardState();
}

class _TaskBoardState extends State<_TaskBoard> {
  final List<TextEditingController> _ctls =
      List.generate(4, (_) => TextEditingController());

  @override
  void dispose() {
    for (final c in _ctls) { c.dispose(); }
    super.dispose();
  }

  void _openSheet(BuildContext context, int qi) {
    final meta = _kQuadrants[qi];
    final color = Color(meta.hex);
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _QuadrantSheet(
        label: meta.label,
        color: color,
        isUrgent: meta.urgency,
        isImportant: meta.important,
        quadrantIndex: qi,
        allTasks: widget.tasks,
        controller: _ctls[qi],
        onAdd: widget.onAdd,
        onToggle: widget.onToggle,
        onDelete: widget.onDelete,
        onUpdate: widget.onUpdate,
      ),
    );
  }

  Widget _buildPieSlice(BuildContext context, int qi) {
    final meta = _kQuadrants[qi];
    final color = Color(meta.hex);
    final qTasks = widget.tasks
        .where((t) => t.isUrgent == meta.urgency && t.isImportant == meta.important)
        .toList();
    final total = qTasks.length;
    final done = qTasks.where((t) => t.done).length;

    BorderRadius radius;
    if (qi == 0) {
      radius = const BorderRadius.only(topLeft: Radius.circular(200));
    } else if (qi == 1) {
      radius = const BorderRadius.only(topRight: Radius.circular(200));
    } else if (qi == 2) {
      radius = const BorderRadius.only(bottomLeft: Radius.circular(200));
    } else {
      radius = const BorderRadius.only(bottomRight: Radius.circular(200));
    }

    // Calculate dynamic padding to offset the text slightly toward the wide end of the pie slice
    // Top-Left (qi=0): push down & right
    // Top-Right (qi=1): push down & left
    // Bottom-Left (qi=2): push up & right
    // Bottom-Right (qi=3): push up & left
    final EdgeInsets offsetPadding = EdgeInsets.only(
      top: (qi == 2 || qi == 3) ? 0 : 20,
      bottom: (qi == 0 || qi == 1) ? 0 : 20,
      left: (qi == 1 || qi == 3) ? 0 : 20,
      right: (qi == 0 || qi == 2) ? 0 : 20,
    );

    return GestureDetector(
      onTap: () => _openSheet(context, qi),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: radius,
          border: Border.all(color: color.withValues(alpha: 0.15), width: 1.5),
        ),
        child: Padding(
          padding: offsetPadding,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(meta.icon, color: color, size: 20),
              const SizedBox(height: 5),
              Text(
                meta.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body(size: 12, weight: FontWeight.w700, color: color),
              ),
              const SizedBox(height: 2),
              Text(
                total == 0 ? '0 tasks' : '$done / $total done',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body(size: 10, color: color.withValues(alpha: 1.0)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Text(
              'Focus Matrix',
              style: AppTypography.body(
                size: 18,
                weight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Circular Matrix
        Center(
          child: AspectRatio(
            aspectRatio: 1,
            child: Stack(
              children: [
                // Inner circle structure
                Align(
                  alignment: Alignment.center,
                  child: FractionallySizedBox(
                    widthFactor: 1.0,
                    heightFactor: 1.0,
                    child: Column(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(child: _buildPieSlice(context, 0)),
                              const SizedBox(width: 4),
                              Expanded(child: _buildPieSlice(context, 1)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(child: _buildPieSlice(context, 2)),
                              const SizedBox(width: 4),
                              Expanded(child: _buildPieSlice(context, 3)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Center White Circle Total Tasks
                Align(
                  alignment: Alignment.center,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () async {
                        HapticFeedback.mediumImpact();
                        await context.push('/eisenhower-board');
                        widget.onRefresh?.call();
                      },
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: AppColors.cardSurface,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 15,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${widget.tasks.where((t) => !t.done).length}',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary,
                                height: 1.0,
                                letterSpacing: -1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Board',
                              style: AppTypography.body(
                                size: 10,
                                weight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Quadrant Bottom Sheet

class _QuadrantSheet extends StatefulWidget {
  const _QuadrantSheet({
    required this.label,
    required this.color,
    required this.isUrgent,
    required this.isImportant,
    required this.quadrantIndex,
    required this.allTasks,
    required this.controller,
    required this.onAdd,
    required this.onToggle,
    required this.onDelete,
    required this.onUpdate,
  });

  final String label;
  final Color color;
  final bool isUrgent;
  final bool isImportant;
  final int quadrantIndex;
  final List<QuickTask> allTasks;
  final TextEditingController controller;
  final QuickTask Function(String, bool, bool) onAdd;
  final ValueChanged<String> onToggle;
  final ValueChanged<String> onDelete;
  final ValueChanged<QuickTask> onUpdate;

  @override
  State<_QuadrantSheet> createState() => _QuadrantSheetState();
}

class _QuadrantSheetState extends State<_QuadrantSheet> {
  late List<QuickTask> _localAll;

  @override
  void initState() {
    super.initState();
    _localAll = List.from(widget.allTasks);
  }

  List<QuickTask> get _qTasks => _localAll
      .where((t) =>
          t.isUrgent == widget.isUrgent &&
          t.isImportant == widget.isImportant)
      .toList();

  void _add() {
    final text = widget.controller.text.trim();
    if (text.isEmpty) return;
    if (_qTasks.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Max 5 tasks allowed in this category'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    // Use the task created & persisted by the parent so both share the same UUID.
    // Previously a second QuickTask with a NEW uuid was created here, causing
    // toggle/delete to silently fail in the parent (wrong id) -> ghost task bug.
    final newTask = widget.onAdd(text, widget.isUrgent, widget.isImportant);
    setState(() => _localAll = [..._localAll, newTask]);
    widget.controller.clear();
  }

  void _toggle(QuickTask task) {
    widget.onToggle(task.id);
    setState(() {
      final i = _localAll.indexWhere((t) => t.id == task.id);
      if (i >= 0) {
        _localAll = List.from(_localAll);
        _localAll[i] = task.copyWith(done: !task.done);
      }
    });
  }

  void _delete(QuickTask task) {
    widget.onDelete(task.id);
    setState(() =>
        _localAll = _localAll.where((t) => t.id != task.id).toList());
  }

  void _update(QuickTask updated) {
    widget.onUpdate(updated);
    setState(() {
      final i = _localAll.indexWhere((t) => t.id == updated.id);
      if (i >= 0) _localAll = List.from(_localAll)..[i] = updated;
    });
  }

  @override
  Widget build(BuildContext context) {
    final qTasks = _qTasks;
    final done = qTasks.where((t) => t.done).length;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + kBottomNavigationBarHeight + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.surfaceRaised,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header row
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: widget.color.withValues(alpha: 0.35)),
                ),
                child: Text(
                  widget.label,
                  style: AppTypography.mono(
                    size: 12,
                    weight: FontWeight.w800,
                    color: widget.color,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$done / ${qTasks.length} done',
                style: AppTypography.body(
                    size: 13, color: AppColors.textSecondary),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Task list
          if (qTasks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No tasks yet - add one below!',
                style:
                    AppTypography.body(size: 14, color: AppColors.textMuted),
              ),
            )
          else
            ...qTasks.map((task) => _MatrixTaskChip(
                  key: ValueKey(task.id),
                  task: task,
                  accentColor: widget.color,
                  quadrantIndex: widget.quadrantIndex,
                  onToggle: () => _toggle(task),
                  onDelete: () => _delete(task),
                  onUpdate: _update,
                )),

          const SizedBox(height: 12),

          // Add row
          if (qTasks.length < 5)
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: TextField(
                      controller: widget.controller,
                      onSubmitted: (_) => _add(),
                      autofocus: false,
                      textAlignVertical: TextAlignVertical.center,
                      style: AppTypography.body(
                        size: 14,
                        weight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText:
                            'Add to ${widget.label.toLowerCase()}...',
                        hintStyle: AppTypography.body(
                            size: 14, color: AppColors.textMuted),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 0),
                        filled: true,
                        fillColor: AppColors.cardSurface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: widget.color.withValues(alpha: 0.6),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _add,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: widget.color,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add_rounded,
                        color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// Matrix Task Chip (used in sheet)

class _MatrixTaskChip extends StatefulWidget {
  const _MatrixTaskChip({
    super.key,
    required this.task,
    required this.accentColor,
    required this.quadrantIndex,
    required this.onToggle,
    required this.onDelete,
    required this.onUpdate,
  });

  final QuickTask task;
  final Color accentColor;
  /// 0=Do it, 1=Schedule it, 2=Delegate it, 3=Skip it
  final int quadrantIndex;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final ValueChanged<QuickTask> onUpdate;

  @override
  State<_MatrixTaskChip> createState() => _MatrixTaskChipState();
}
class _MatrixTaskChipState extends State<_MatrixTaskChip> {
  static const _months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

  void _cyclePriority() {
    final cur = widget.task.priority;
    final String? next;
    if (cur == null) {
      next = 'P1';
    } else if (cur == 'P1') {
      next = 'P2';
    } else if (cur == 'P2') {
      next = 'P3';
    } else if (cur == 'P3') {
      next = 'P4';
    } else if (cur == 'P4') {
      next = 'P5';
    } else {
      next = null; // P5 -> clear
    }
    widget.onUpdate(widget.task.copyWith(priority: next));
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final initial = widget.task.deadline != null
        ? DateTime.tryParse(widget.task.deadline!) ?? now
        : now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 730)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: widget.accentColor,
            onPrimary: Colors.white,
            surface: AppColors.cardSurface,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      final iso = '${picked.year}-${picked.month.toString().padLeft(2,'0')}-${picked.day.toString().padLeft(2,'0')}';
      widget.onUpdate(widget.task.copyWith(deadline: iso));
    }
  }

  Future<void> _pickDelegatee() async {
    final ctrl = TextEditingController(text: widget.task.delegatee ?? '');
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delegate to',
          style: AppTypography.body(size: 16, weight: FontWeight.w700, color: AppColors.textPrimary),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          style: AppTypography.body(size: 15, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Person name...',
            hintStyle: AppTypography.body(size: 15, color: AppColors.textMuted),
            prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.textMuted, size: 20),
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (_) => Navigator.pop(ctx),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: AppTypography.body(size: 14, color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () {
              final name = ctrl.text.trim();
              widget.onUpdate(widget.task.copyWith(delegatee: name.isEmpty ? null : name));
              Navigator.pop(ctx);
            },
            child: Text('Save', style: AppTypography.body(size: 14, weight: FontWeight.w700, color: widget.accentColor)),
          ),
        ],
      ),
    ).whenComplete(() => ctrl.dispose());
  }

  Widget? _buildMetaBadge() {
    switch (widget.quadrantIndex) {
      // Do it -> priority flag
      case 0:
        final p = widget.task.priority;
        // P1=Red, P2=Orange, P3=Blue, P4=Purple, P5=Green, null=muted
        final Color pColor = p == 'P1'
            ? AppColors.p1
            : p == 'P2'
                ? AppColors.p2
                : p == 'P3'
                    ? AppColors.p3
                    : p == 'P4'
                        ? AppColors.p4
                        : p == 'P5'
                            ? AppColors.p5
                            : AppColors.textMuted;
        return GestureDetector(
          onTap: _cyclePriority,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: p != null
                  ? pColor.withValues(alpha: 0.12)
                  : AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: p != null
                    ? pColor.withValues(alpha: 0.45)
                    : AppColors.textMuted.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.flag_rounded,
                  size: 13,
                  color: pColor,
                ),
                const SizedBox(width: 4),
                Text(
                  p ?? 'P-',
                  style: AppTypography.mono(
                    size: 11,
                    weight: FontWeight.w700,
                    color: pColor,
                  ),
                ),
              ],
            ),
          ),
        );


      // Schedule it -> deadline date
      case 1:
        final dl = widget.task.deadline;
        String label = 'Date';
        bool hasDate = false;
        bool isOverdue = false;
        if (dl != null) {
          final dt = DateTime.tryParse(dl);
          if (dt != null) {
            hasDate = true;
            isOverdue = dt.isBefore(DateTime.now().subtract(const Duration(days: 1)));
            label = '${_months[dt.month - 1]} ${dt.day}';
          }
        }
        return GestureDetector(
          onTap: _pickDeadline,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: hasDate
                  ? (isOverdue
                      ? Colors.red.withValues(alpha: 0.10)
                      : widget.accentColor.withValues(alpha: 0.10))
                  : AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: hasDate
                    ? (isOverdue
                        ? Colors.red.withValues(alpha: 0.4)
                        : widget.accentColor.withValues(alpha: 0.4))
                    : AppColors.textMuted.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_month_rounded,
                  size: 13,
                  color: hasDate
                      ? (isOverdue ? Colors.red : widget.accentColor)
                      : AppColors.textMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: AppTypography.mono(
                    size: 11,
                    weight: FontWeight.w600,
                    color: hasDate
                        ? (isOverdue ? Colors.red : widget.accentColor)
                        : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        );

      // Delegate it -> person name (sujood icon for prayer context)
      case 2:
        final name = widget.task.delegatee;
        return GestureDetector(
          onTap: _pickDelegatee,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: name != null
                  ? widget.accentColor.withValues(alpha: 0.10)
                  : AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: name != null
                    ? widget.accentColor.withValues(alpha: 0.4)
                    : AppColors.textMuted.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.person_outline_rounded,
                  size: 13,
                  color: name != null ? widget.accentColor : AppColors.textMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  name ?? 'Who?',
                  style: AppTypography.mono(
                    size: 11,
                    weight: FontWeight.w600,
                    color: name != null ? widget.accentColor : AppColors.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );

      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = widget.task.done;
    final badge = _buildMetaBadge();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: widget.onToggle,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 52,
                padding: const EdgeInsets.only(left: 8, right: 10),
                decoration: BoxDecoration(
                  color: done
                      ? widget.accentColor.withValues(alpha: 0.08)
                      : AppColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: done
                        ? widget.accentColor.withValues(alpha: 0.3)
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    // Checkbox
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: done ? widget.accentColor : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: done
                              ? widget.accentColor
                              : AppColors.textMuted.withValues(alpha: 0.6),
                          width: 1.5,
                        ),
                      ),
                      child: done
                          ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    // Title
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Text(
                          widget.task.title,
                          style: AppTypography.body(
                            size: 15,
                            weight: done ? FontWeight.w400 : FontWeight.w500,
                            color: done ? AppColors.textMuted : AppColors.textPrimary,
                          ).copyWith(
                            decoration: done ? TextDecoration.lineThrough : null,
                            decorationColor: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                    // Metadata badge (right side)
                    if (badge != null) ...[
                      const SizedBox(width: 8),
                      badge,
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Delete button
          GestureDetector(
            onTap: widget.onDelete,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.textMuted.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.textMuted.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.close_rounded,
                size: 18,
                color: AppColors.textPrimary.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
