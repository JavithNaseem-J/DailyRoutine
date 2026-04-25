import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/quotes.dart';
import '../../core/models/prayer_times.dart';
import '../../core/models/quick_task.dart';
import '../../core/services/date_service.dart';
import '../../core/services/hive_service.dart';
import '../../core/services/prayer_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../sessions/providers/sessions_provider.dart';
import '../../main.dart' show deviceId, sharedPrefs;
import 'package:quran/quran.dart' as quran;

// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ ProgressItem Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

class ProgressItem {
  ProgressItem({String? id, this.name = '', this.progress = 0, this.note = ''})
    : id = id ?? const Uuid().v4();

  final String id;
  String name;
  int progress; // 0Ã¢â‚¬â€œ100
  String note;

  factory ProgressItem.fromJson(Map<String, dynamic> j) => ProgressItem(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    progress: j['progress'] as int? ?? 0,
    note: j['note'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'progress': progress,
    'note': note,
  };
}

// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
// Home Screen
// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

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

  // In Progress board (replaces Today's Focus)
  List<ProgressItem> _progressItems = [];
  Timer? _progressDebounce;

  // Task Board
  List<QuickTask> _quickTasks = [];
  final TextEditingController _quickController = TextEditingController();

  // Water + Walk (no outer header)
  int _waterMl = 0;
  int _walkM = 0;
  static const int _waterTarget = 4000; // ml
  static const int _walkTarget = 4000; // m

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );
    _weekStrip = dateService.buildWeekStripWithDates();
    _todayPrayers = prayerService.getTodayPrayerTimes();
    _prayerData = prayerService.getPrayerData(DateTime.now());
    _loadPlannedEvents();
    _loadProgressItems();
    _loadQuickTasks();
    _loadGoals();
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
    _confettiController.dispose();
    _prayerTimer.cancel();
    _quickController.dispose();
    _progressDebounce?.cancel();
    super.dispose();
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬ In Progress Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  // Week Planner
  void _loadPlannedEvents() {
    final map = <String, String>{};
    for (final d in _weekStrip) {
      final key = 'event_${dateService.keyFor(d.date)}';
      final val = sharedPrefs.getString(key);
      if (val != null) map[dateService.keyFor(d.date)] = val;
    }
    setState(() => _plannedEvents = map);
  }

  void _savePlannedEvent(DateTime date, String text) {
    final key = 'event_${dateService.keyFor(date)}';
    if (text.isEmpty) {
      sharedPrefs.remove(key);
      setState(() => _plannedEvents.remove(dateService.keyFor(date)));
    } else {
      sharedPrefs.setString(key, text);
      setState(() => _plannedEvents[dateService.keyFor(date)] = text);
    }
  }

  void _showEventEditor(DateTime date, String existingText) {
    final ctrl = TextEditingController(text: existingText);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              style: AppTypography.body(
                size: 16,
                weight: FontWeight.w600,
                color: Colors.black,
              ),
              decoration: InputDecoration(
                hintText: '',
                hintStyle: AppTypography.body(size: 16, color: Colors.black38),
                filled: true,
                fillColor: Color(0xFFF3F4F6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
            SizedBox(height: 20),
            Row(
              children: [
                if (existingText.isNotEmpty)
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: Colors.black, width: 2),
                      ),
                      onPressed: () {
                        _savePlannedEvent(date, '');
                        Navigator.pop(ctx);
                        if (Navigator.canPop(ctx)) {
                          Navigator.pop(ctx); // Close viewer if open
                        }
                      },
                      child: Text(
                        'Delete',
                        style: AppTypography.body(
                          size: 16,
                          weight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                if (existingText.isNotEmpty) const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      _savePlannedEvent(date, ctrl.text.trim());
                      Navigator.pop(ctx);
                    },
                    child: Text(
                      'Save',
                      style: AppTypography.body(
                        size: 16,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showEventViewer(DateTime date, String text) {
    showGeneralDialog(
      context: context,
      barrierColor: Colors.black12,
      barrierDismissible: true,
      barrierLabel: 'Close Popup',
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, anim1, anim2) {
        return Align(
          alignment: Alignment.topCenter,
          child: Container(
            margin: const EdgeInsets.only(
              top: 210,
              left: 24,
              right: 24,
            ), // Directly under the date strip
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.black54,
                        size: 20,
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    text,
                    style: AppTypography.body(
                      size: 18,
                      weight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.05),
            end: Offset.zero,
          ).animate(anim1),
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
    );
  }

  void _loadProgressItems() {
    final raw = sharedPrefs.getString(
      'progress_items_${dateService.todayKey()}',
    );
    if (raw == null) return;
    try {
      final list = jsonDecode(raw) as List;
      setState(() {
        _progressItems = list
            .map(
              (e) => ProgressItem.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
      });
    } catch (_) {}
  }

  void _saveProgressItems() {
    sharedPrefs.setString(
      'progress_items_${dateService.todayKey()}',
      jsonEncode(_progressItems.map((e) => e.toJson()).toList()),
    );
  }

  void _addProgressItem() {
    if (_progressItems.length >= 3) return;
    setState(() => _progressItems = [..._progressItems, ProgressItem()]);
    _saveProgressItems();
  }

  void _updateProgressItem(int i, {String? name, int? progress, String? note}) {
    final c = _progressItems[i];
    final updated = ProgressItem(
      id: c.id,
      name: name ?? c.name,
      progress: progress ?? c.progress,
      note: note ?? c.note,
    );
    setState(() => _progressItems = [..._progressItems]..[i] = updated);
    _progressDebounce?.cancel();
    _progressDebounce = Timer(
      const Duration(milliseconds: 400),
      _saveProgressItems,
    );
  }

  void _deleteProgressItem(int i) {
    setState(() => _progressItems = [..._progressItems]..removeAt(i));
    _saveProgressItems();
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬ Task Board Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  void _loadQuickTasks() {
    setState(() {
      _quickTasks = hiveService.readQuickTasks('global');
    });
    supabaseService.fetchQuickTasks('global', deviceId).then((
      remote,
    ) {
      if (!mounted) return;
      setState(() => _quickTasks = remote);
      hiveService.writeQuickTasks('global', remote);
    });
  }

  void _addQuickTask() {
    final text = _quickController.text.trim();
    if (text.isEmpty || _quickTasks.length >= 5) return;
    final task = QuickTask(
      id: const Uuid().v4(),
      date: 'global',
      title: text,
    );
    setState(() {
      _quickTasks = [..._quickTasks, task];
      _quickController.clear();
    });
    hiveService.writeQuickTasks('global', _quickTasks);
    supabaseService.upsertQuickTask(task, deviceId).catchError((_) {});
  }

  void _toggleQuickTask(int i) {
    final updated = _quickTasks[i].copyWith(done: !_quickTasks[i].done);
    setState(() => _quickTasks = [..._quickTasks]..[i] = updated);
    hiveService.writeQuickTasks('global', _quickTasks);
    supabaseService.upsertQuickTask(updated, deviceId).catchError((_) {});
  }

  void _deleteQuickTask(int i) {
    final task = _quickTasks[i];
    setState(() => _quickTasks = [..._quickTasks]..removeAt(i));
    hiveService.writeQuickTasks('global', _quickTasks);
    supabaseService.deleteQuickTask(task.id).catchError((_) {});
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬ Goals Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  void _loadGoals() {
    final today = dateService.todayKey();
    setState(() {
      _waterMl = sharedPrefs.getInt('goal_water_$today') ?? 0;
      _walkM = sharedPrefs.getInt('goal_walk_$today') ?? 0;
    });
  }

  void _updateWater(int delta) {
    final v = (_waterMl + delta).clamp(0, _waterTarget);
    setState(() => _waterMl = v);
    sharedPrefs.setInt('goal_water_${dateService.todayKey()}', v);
  }

  void _updateWalk(int delta) {
    final v = (_walkM + delta).clamp(0, _walkTarget);
    setState(() => _walkM = v);
    sharedPrefs.setInt('goal_walk_${dateService.todayKey()}', v);
  }

  // ──────────────── Greeting ────────────────
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
    final quote = Quotes.today();
    final completionPct = ref.watch(completionPctProvider);

    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                SizedBox(height: 16),

                // Ã¢â€â‚¬Ã¢â€â‚¬ Header Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
                Row(
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
                        greeting.text,
                        style: AppTypography.screenTitle(
                          color: AppColors.textPrimary,
                        ),
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

                // Ã¢â€â‚¬Ã¢â€â‚¬ Progress bar Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
                _DailyProgressBar(completionPct: completionPct),

                SizedBox(height: 16),

                // Ã¢â€â‚¬Ã¢â€â‚¬ Week strip Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
                _WeekStrip(
                  days: _weekStrip,
                  plannedEvents: _plannedEvents,
                  onDateTap: (date) {
                    final key = dateService.keyFor(date);
                    if (_plannedEvents.containsKey(key)) {
                      _showEventViewer(date, _plannedEvents[key]!);
                    }
                  },
                  onDateLongPress: (date) {
                    final key = dateService.keyFor(date);
                    _showEventEditor(date, _plannedEvents[key] ?? '');
                  },
                ),

                SizedBox(height: 20),

                // Ã¢â€â‚¬Ã¢â€â‚¬ Quote Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
                _QuoteCard(text: quote.text, attribution: quote.attribution),

                SizedBox(height: 16),

                // Ã¢â€â‚¬Ã¢â€â‚¬ Prayer card Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
                _PrayerCard(prayer: _prayerData, todayPrayers: _todayPrayers),

                SizedBox(height: 20),

                _QuranCard(
                  lastPage: sharedPrefs.getInt('quran_last_page') ?? 1,
                  onTap: () async {
                    await context.push('/quran');
                    setState(() {});
                  },
                ),

                SizedBox(height: 20),

                // Ã¢â€â‚¬Ã¢â€â‚¬ In Progress Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
                _InProgressSection(
                  items: _progressItems,
                  onAdd: _addProgressItem,
                  onUpdate: _updateProgressItem,
                  onDelete: _deleteProgressItem,
                ),

                SizedBox(height: 20),

                // Ã¢â€â‚¬Ã¢â€â‚¬ Water + Walk (no header) Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
                _WaterWalkRow(
                  waterMl: _waterMl,
                  waterTarget: _waterTarget,
                  walkM: _walkM,
                  walkTarget: _walkTarget,
                  onWaterTap: _updateWater,
                  onWalkTap: _updateWalk,
                ),

                SizedBox(height: 20),

                // Ã¢â€â‚¬Ã¢â€â‚¬ Task Board Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
                _TaskBoard(
                  tasks: _quickTasks,
                  controller: _quickController,
                  onAdd: _addQuickTask,
                  onDelete: _deleteQuickTask,
                  onToggle: _toggleQuickTask,
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

// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
// Daily Progress Bar
// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

class _DailyProgressBar extends StatelessWidget {
  const _DailyProgressBar({required this.completionPct});
  final int completionPct;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Today's Progress",
                style: AppTypography.body(
                  size: 13,
                  weight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '$completionPct%',
                style: AppTypography.mono(
                  size: 12,
                  weight: FontWeight.w600,
                  color: completionPct >= 80
                      ? AppColors.complete
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          LayoutBuilder(
            builder: (_, constraints) {
              return Stack(
                children: [
                  Container(
                    height: 6,
                    width: constraints.maxWidth,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceRaised,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOut,
                    height: 6,
                    width: constraints.maxWidth * (completionPct / 100),
                    decoration: BoxDecoration(
                      color: AppColors.complete,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────
// Week Strip
// ──────────────────────────────────────────────────

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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: days.map((d) {
        final hasEvent = plannedEvents.containsKey(dateService.keyFor(d.date));
        return GestureDetector(
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
        );
      }).toList(),
    );
  }
}

// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
// Quote Card
// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({required this.text, required this.attribution});
  final String text;
  final String attribution;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: AppColors.primary, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quote of the Day',
            style: AppTypography.label(color: AppColors.textMuted),
          ),
          SizedBox(height: 6),
          Text(
            text,
            textAlign: TextAlign.justify,
            style: AppTypography.body(
              size: 13,
              style: FontStyle.italic,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          SizedBox(height: 6),
          Text(
            attribution,
            style: AppTypography.mono(size: 10, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
// Prayer Card Ã¢â‚¬â€ top-aligned + full schedule at bottom
// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

class _PrayerCard extends ConsumerWidget {
  const _PrayerCard({required this.prayer, required this.todayPrayers});
  final ({String name, DateTime adhaan, DateTime prayerStart}) prayer;
  final PrayerTimes todayPrayers;

  String _fmt(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ampm';
  }

  String _fmtShort(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prayerList = todayPrayers.asOrderedList();
    final now = DateTime.now();
    final prayerStates = ref.watch(sessionsProvider).value?.dailyState.prayerStates ?? {};

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ã¢â€â‚¬Ã¢â€â‚¬ TOP: icon+label (top-left) + times (top-right) Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // LEFT - top-aligned icon, label, name
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.mosque_outlined,
                              color: Colors.white54,
                              size: 14,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Next Prayer',
                              style: AppTypography.label(color: Colors.white54),
                            ),
                          ],
                        ),
                        SizedBox(height: 6),
                        Text(
                          prayer.name,
                          style: AppTypography.body(
                            size: 24,
                            weight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
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
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              rStr,
                              style: AppTypography.mono(
                                size: 11,
                                color: Colors.white54,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
                const Spacer(),
                // RIGHT - adhaan + prayer start
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.volume_up_rounded,
                          size: 10,
                          color: Colors.white38,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Adhaan',
                          style: AppTypography.label(color: Colors.white38),
                        ),
                      ],
                    ),
                    Text(
                      _fmt(prayer.adhaan),
                      style: AppTypography.mono(
                        size: 15,
                        weight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 10,
                          color: AppColors.complete,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Prayer',
                          style: AppTypography.label(color: AppColors.complete),
                        ),
                      ],
                    ),
                    Text(
                      _fmt(prayer.prayerStart),
                      style: AppTypography.mono(
                        size: 15,
                        weight: FontWeight.w700,
                        color: AppColors.complete,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(height: 14),
          Divider(color: Colors.white12, height: 1),
          SizedBox(height: 12),

          // Ã¢â€â‚¬Ã¢â€â‚¬ BOTTOM: full 5-prayer schedule Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: prayerList.map((p) {
              final isPast = p.time.isBefore(now);
              final isNext = p.name == prayer.name;
              return Column(
                children: [
                  Text(
                    p.name[0].toUpperCase() + p.name.substring(1),
                    style: AppTypography.label(
                      color: isNext
                          ? AppColors.complete
                          : isPast
                          ? Colors.white24
                          : Colors.white38,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    _fmtShort(p.time),
                    style: AppTypography.mono(
                      size: 11,
                      weight: isNext ? FontWeight.w700 : FontWeight.w400,
                      color: isNext
                          ? Colors.white
                          : isPast
                          ? Colors.white24
                          : Colors.white54,
                    ),
                  ),
                  SizedBox(height: 5),
                  GestureDetector(
                    onTap: () {
                      ref.read(sessionsProvider.notifier).togglePrayer(p.name);
                    },
                    child: Container(
                      width: 22,
                      height: 22,
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
                          ? Icon(Icons.check, size: 14, color: AppColors.complete)
                          : null,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────
// In Progress Section
// ──────────────────────────────────────────────────

// ──────────────────────────────────────────────────
// In Progress — horizontal scroll, colorful cards
// ──────────────────────────────────────────────────

class _InProgressSection extends StatelessWidget {
  const _InProgressSection({
    required this.items,
    required this.onAdd,
    required this.onUpdate,
    required this.onDelete,
  });

  final List<ProgressItem> items;
  final VoidCallback onAdd;
  final void Function(int i, {String? name, int? progress, String? note})
  onUpdate;
  final ValueChanged<int> onDelete;

  @override
  Widget build(BuildContext context) {
    final bgColors = [
      AppColors.surfaceRaised,
      AppColors.surfaceRaised,
      AppColors.surfaceRaised,
    ];
    final accents = [
      AppColors.primary,
      AppColors.primary,
      AppColors.primary,
    ];
    const icons = [
      Icons.local_fire_department_rounded,
      Icons.bolt_rounded,
      Icons.diamond_rounded,
    ];

    final atLimit = items.length >= 3;
    final cardWidth = MediaQuery.of(context).size.width * 0.55;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ────────────────────────────────────────
        Row(
          children: [
            Text(
              'In Progress',
              style: AppTypography.body(
                size: 20,
                weight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.local_fire_department_rounded,
              color: AppColors.textPrimary,
              size: 22,
            ),
            const SizedBox(width: 8),
            if (items.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${items.length}/3',
                  style: AppTypography.mono(
                    size: 10,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            const Spacer(),
            GestureDetector(
              onTap: atLimit ? null : onAdd,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: atLimit ? AppColors.cardSurface : AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add,
                      size: 14,
                      color: atLimit ? AppColors.textMuted : Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      atLimit ? 'Full' : 'Add',
                      style: AppTypography.mono(
                        size: 11,
                        color: atLimit ? AppColors.textMuted : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        SizedBox(height: 12),

        // Ã¢â€â‚¬Ã¢â€â‚¬ Cards Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
        if (items.isNotEmpty)
          SizedBox(
            height: 154,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              itemBuilder: (_, i) => _ProgressCard(
                key: ValueKey(items[i].id),
                item: items[i],
                index: i,
                width: cardWidth,
                bgColor: bgColors[i % bgColors.length],
                accent: accents[i % accents.length],
                cardIcon: icons[i % icons.length],
                onNameChanged: (v) => onUpdate(i, name: v),
                onProgressChanged: (v) => onUpdate(i, progress: v),
                onNoteChanged: (v) => onUpdate(i, note: v),
                onDelete: () => onDelete(i),
              ),
            ),
          ),
      ],
    );
  }
}

// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
// Progress Card Ã¢â‚¬â€ colorful horizontal card
// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

class _ProgressCard extends StatefulWidget {
  const _ProgressCard({
    super.key,
    required this.item,
    required this.index,
    required this.width,
    required this.bgColor,
    required this.accent,
    required this.cardIcon,
    required this.onNameChanged,
    required this.onProgressChanged,
    required this.onNoteChanged,
    required this.onDelete,
  });

  final ProgressItem item;
  final int index;
  final double width;
  final Color bgColor;
  final Color accent;
  final IconData cardIcon;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<int> onProgressChanged;
  final ValueChanged<String> onNoteChanged;
  final VoidCallback onDelete;

  @override
  State<_ProgressCard> createState() => _ProgressCardState();
}

class _ProgressCardState extends State<_ProgressCard> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _noteCtrl;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.item.name);
    _noteCtrl = TextEditingController(text: widget.item.note);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _save() {
    widget.onNameChanged(_nameCtrl.text);
    widget.onNoteChanged(_noteCtrl.text);
    setState(() => _isEditing = false);
  }

  void _showEditOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                Icons.edit_rounded,
                color: AppColors.textPrimary,
              ),
              title: Text('Edit', style: AppTypography.body(size: 16)),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _isEditing = true);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline_rounded,
                color: AppColors.moodLow,
              ),
              title: Text(
                'Delete',
                style: AppTypography.body(size: 16, color: AppColors.moodLow),
              ),
              onTap: () {
                Navigator.pop(ctx);
                widget.onDelete();
              },
            ),
            ListTile(
              leading: Icon(
                Icons.close_rounded,
                color: AppColors.textPrimary,
              ),
              title: Text('Cancel', style: AppTypography.body(size: 16)),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pct = widget.item.progress;
    final isComplete = pct >= 100;

    return GestureDetector(
      onLongPress: () => _showEditOptions(context),
      child: Container(
        width: widget.width,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            color: Colors.white,
            child: Stack(
              children: [
                // BLACK BORDER OVERLAY
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.black, width: 2.5),
                    ),
                  ),
                ),

                // MAIN CONTENT COLUMN
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                        child: _isEditing
                            // ── EDIT MODE ──────────────────────────────────
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _noteCtrl,
                                          autofocus: true,
                                          style: AppTypography.body(
                                            size: 16,
                                            weight: FontWeight.w700,
                                            color: Colors.black,
                                          ),
                                          decoration: InputDecoration(
                                            hintText: 'Task Name',
                                            hintStyle: AppTypography.body(
                                              size: 16,
                                              color: Colors.black38,
                                            ),
                                            border: InputBorder.none,
                                            enabledBorder: InputBorder.none,
                                            focusedBorder: InputBorder.none,
                                            filled: false,
                                            isDense: true,
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: _save,
                                        child: Container(
                                          padding: const EdgeInsets.all(7),
                                          decoration: BoxDecoration(
                                            color: Colors.black,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.check_rounded,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: _nameCtrl,
                                      maxLines: null,
                                      expands: true,
                                      style: AppTypography.body(
                                        size: 13,
                                        weight: FontWeight.w500,
                                        color: Colors.black87,
                                        height: 1.35,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Description',
                                        hintStyle: AppTypography.body(
                                          size: 13,
                                          color: Colors.black38,
                                        ),
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        filled: false,
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            // ── READ-ONLY (TOOLTIP) MODE ────────────────────
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _noteCtrl.text.isEmpty
                                              ? 'Task Name'
                                              : _noteCtrl.text,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTypography.body(
                                            size: 16,
                                            weight: FontWeight.w700,
                                            color: _noteCtrl.text.isEmpty
                                                ? Colors.black38
                                                : Colors.black,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        isComplete ? 'DONE' : '$pct%',
                                        style: AppTypography.mono(
                                          size: 16,
                                          weight: FontWeight.w900,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    _nameCtrl.text.isEmpty
                                        ? 'Description'
                                        : _nameCtrl.text,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.body(
                                      size: 13,
                                      weight: FontWeight.w500,
                                      color: _nameCtrl.text.isEmpty
                                          ? Colors.black26
                                          : Colors.black54,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),

                    // PROGRESS BAR — drag/tap zone at the bottom of the column
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanUpdate: (d) {
                        final p = (d.localPosition.dx / widget.width * 100)
                            .clamp(0.0, 100.0)
                            .round();
                        widget.onProgressChanged(p);
                      },
                      onTapDown: (d) {
                        final p = (d.localPosition.dx / widget.width * 100)
                            .clamp(0.0, 100.0)
                            .round();
                        widget.onProgressChanged(p);
                      },
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 6, 18, 14),
                        child: Stack(
                          children: [
                            // Track
                            Container(
                              height: 5,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Color(0xFFE5E7EB),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            // Fill
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 120),
                              curve: Curves.easeOut,
                              height: 5,
                              width:
                                  (widget.width - 36) *
                                  (pct / 100).clamp(0.0, 1.0),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────
class _WaterWalkRow extends StatelessWidget {
  const _WaterWalkRow({
    required this.waterMl,
    required this.waterTarget,
    required this.walkM,
    required this.walkTarget,
    required this.onWaterTap,
    required this.onWalkTap,
  });

  final int waterMl;
  final int waterTarget;
  final int walkM;
  final int walkTarget;
  final ValueChanged<int> onWaterTap;
  final ValueChanged<int> onWalkTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _GoalRing(
            icon: Icons.water_drop_rounded,
            label: 'Water',
            ringColor: Color(0xFF3B82F6),
            fraction: waterMl / waterTarget,
            valueText: '${(waterMl / 1000).toStringAsFixed(1)} L',
            onIncrement: () => onWaterTap(250),
            onDecrement: () => onWaterTap(-250),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _GoalRing(
            icon: Icons.directions_walk_rounded,
            label: 'Walk',
            ringColor: AppColors.complete,
            fraction: walkM / walkTarget,
            valueText: '${(walkM / 1000).toStringAsFixed(1)} km',
            onIncrement: () => onWalkTap(500),
            onDecrement: () => onWalkTap(-500),
          ),
        ),
      ],
    );
  }
}

class _GoalRing extends StatelessWidget {
  const _GoalRing({
    required this.icon,
    required this.label,
    required this.ringColor,
    required this.fraction,
    required this.valueText,
    required this.onIncrement,
    required this.onDecrement,
  });

  final IconData icon;
  final String label;
  final Color ringColor;
  final double fraction;
  final String valueText;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: ringColor, size: 14),
              const SizedBox(width: 5),
              Text(
                label,
                style: AppTypography.body(
                  size: 12,
                  weight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: fraction.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOut,
            builder: (_, value, __) => SizedBox(
              width: 90,
              height: 90,
              child: CustomPaint(
                painter: _ArcPainter(
                  fraction: value,
                  ringColor: ringColor,
                  trackColor: AppColors.surfaceRaised,
                  strokeWidth: 9,
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: value >= 1.0
                        ? Icon(
                            Icons.check_circle_rounded,
                            color: ringColor,
                            size: 32,
                          )
                        : Text(
                            valueText,
                            textAlign: TextAlign.center,
                            style: AppTypography.mono(
                              size: 12,
                              weight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _GoalBtn(icon: Icons.remove, onTap: onDecrement),
              const SizedBox(width: 22),
              _GoalBtn(
                icon: Icons.add,
                onTap: onIncrement,
                filled: true,
                color: ringColor,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GoalBtn extends StatelessWidget {
  const _GoalBtn({
    required this.icon,
    required this.onTap,
    this.filled = false,
    this.color,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool filled;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled
              ? (color ?? AppColors.primary)
              : AppColors.surfaceRaised,
        ),
        child: Icon(
          icon,
          size: 16,
          color: filled ? Colors.white : AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  const _ArcPainter({
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
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, -1.5708, 6.2832, false, paint..color = trackColor);
    if (fraction > 0) {
      canvas.drawArc(
        rect,
        -1.5708,
        6.2832 * fraction,
        false,
        paint..color = ringColor,
      );
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.fraction != fraction || old.ringColor != ringColor;
}

// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
// Task Board Ã¢â‚¬â€ clean two-section design (per wireframe)
// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

class _TaskBoard extends StatelessWidget {
  const _TaskBoard({
    required this.tasks,
    required this.controller,
    required this.onAdd,
    required this.onDelete,
    required this.onToggle,
  });

  final List<QuickTask> tasks;
  final TextEditingController controller;
  final VoidCallback onAdd;
  final ValueChanged<int> onDelete;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    final atLimit = tasks.length >= 5;
    final doneCount = tasks.where((t) => t.done).length;
    final allDone = tasks.length == 5 && doneCount == 5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.checklist_rounded,
              color: Color(0xFF1A1A1A),
              size: 22,
            ),
            const SizedBox(width: 6),
            Text(
              'Task Board',
              style: AppTypography.body(
                size: 20,
                weight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),

        SizedBox(height: 10),

        // Ã¢â€â‚¬Ã¢â€â‚¬ Add Task input Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
        Container(
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.fromLTRB(16, 4, 10, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: !atLimit,
                  onSubmitted: (_) => onAdd(),
                  style: AppTypography.body(
                    size: 14,
                    weight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: atLimit ? 'Max 5 tasks' : 'Add Task',
                    hintStyle: AppTypography.body(
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              GestureDetector(
                onTap: atLimit ? null : onAdd,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: atLimit
                        ? AppColors.surfaceRaised
                        : AppColors.primary,
                  ),
                  child: Icon(
                    Icons.auto_awesome,
                    size: 17,
                    color: atLimit ? AppColors.textMuted : Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Ã¢â€â‚¬Ã¢â€â‚¬ Pending section Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
        if (tasks.any((t) => !t.done)) ...[
          SizedBox(height: 18),
          Text(
            'TO DO',
            style: AppTypography.body(
              size: 12,
              weight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 8),
          ...List.generate(tasks.length, (i) {
            final task = tasks[i];
            if (task.done) return const SizedBox.shrink();
            return _TaskCard(
              key: ValueKey('pd_${task.id}'),
              task: task,
              index: i,
              onToggle: onToggle,
              onDelete: onDelete,
            );
          }),
        ],

        // Ã¢â€â‚¬Ã¢â€â‚¬ Done section Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
        if (tasks.any((t) => t.done)) ...[
          SizedBox(height: 16),
          Row(
            children: [
              Text(
                'DONE',
                style: AppTypography.label(color: AppColors.complete),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.completeFill,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$doneCount',
                  style: AppTypography.mono(
                    size: 10,
                    weight: FontWeight.w700,
                    color: AppColors.complete,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          ...List.generate(tasks.length, (i) {
            final task = tasks[i];
            if (!task.done) return const SizedBox.shrink();
            return _TaskCard(
              key: ValueKey('dn_${task.id}'),
              task: task,
              index: i,
              onToggle: onToggle,
              onDelete: onDelete,
            );
          }),
        ],

        // Ã¢â€â‚¬Ã¢â€â‚¬ All done banner Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
        if (allDone) ...[
          SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.completeFill,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.complete.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.military_tech_rounded,
                  color: AppColors.complete,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'All tasks done!',
                  style: AppTypography.body(
                    size: 13,
                    weight: FontWeight.w600,
                    color: Color(0xFF166634),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 8),
        ],
      ],
    );
  }
}

// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
// Individual Task Card
// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    super.key,
    required this.task,
    required this.index,
    required this.onToggle,
    required this.onDelete,
  });

  final QuickTask task;
  final int index;
  final ValueChanged<int> onToggle;
  final ValueChanged<int> onDelete;

  @override
  Widget build(BuildContext context) {
    final done = task.done;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Slidable(
          key: ValueKey('dis_${task.id}'),
          endActionPane: ActionPane(
            motion: const BehindMotion(),
            children: [
              SlidableAction(
                onPressed: (_) {
                  HapticFeedback.mediumImpact();
                  onDelete(index);
                },
                backgroundColor: Color(0xFFD44060),
                icon: Icons.delete_sweep_rounded,
                label: 'Delete',
              ),
            ],
          ),
          startActionPane: ActionPane(
            motion: const BehindMotion(),
            children: [
              SlidableAction(
                onPressed: (_) {
                  HapticFeedback.lightImpact();
                  onToggle(index);
                },
                backgroundColor: done ? Colors.orange : AppColors.complete,
                icon: done ? Icons.undo_rounded : Icons.check_rounded,
                label: done ? 'Undo' : 'Complete',
              ),
            ],
          ),
          child: GestureDetector(
            onTap: () => onToggle(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: done ? AppColors.completeFill : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: done
                      ? AppColors.complete.withValues(alpha: 0.35)
                      : AppColors.border,
                ),
                boxShadow: done
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Row(
                children: [
                    // Rounded-square checkbox
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: done ? AppColors.complete : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: done ? AppColors.complete : AppColors.textMuted,
                          width: 1.5,
                        ),
                      ),
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 400),
                        scale: done ? 1.0 : 0.0,
                        curve: Curves.elasticOut,
                        child: Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  const SizedBox(width: 12),
                  // Task text
                  Expanded(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 250),
                      style: done
                          ? AppTypography.body(
                              size: 15,
                              color: AppColors.complete,
                            ).copyWith(
                              decoration: TextDecoration.lineThrough,
                              decorationColor: AppColors.complete,
                            )
                          : AppTypography.body(
                              size: 15,
                              weight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                      child: Text(task.title),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => onDelete(index),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        size: 20,
                        color: AppColors.textMuted.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────
// Quran Card
// ──────────────────────────────────────────────────

class _QuranCard extends StatelessWidget {
  final int lastPage;
  final VoidCallback onTap;

  const _QuranCard({required this.lastPage, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final pageData = quran.getPageData(lastPage);
    final surahName = pageData.isNotEmpty
        ? quran.getSurahName(pageData.first['surah'])
        : 'Al-Fatihah';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.menu_book_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Quran',
                        style: AppTypography.mono(
                          size: 11,
                          color: Colors.white70,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 12,
                            color: Colors.white70,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '15 mins',
                            style: AppTypography.mono(
                              size: 11,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Surah $surahName',
                    style: AppTypography.body(
                      size: 18,
                      weight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: lastPage / 604,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Page $lastPage/604',
                        style: AppTypography.mono(
                          size: 10,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white54,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
