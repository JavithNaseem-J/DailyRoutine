import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/daily_state.dart';
import '../models/quick_task.dart';
import '../models/todays_focus.dart';
import '../models/session.dart';

// HiveService — local write-ahead cache
// On web: _initialized stays false → all reads return empty defaults,
//          all writes are no-ops. Supabase is the sole data source on web.
// On mobile: boxes are opened in init(), called from main() before runApp.

class HiveService {
  static final HiveService _instance = HiveService._();
  factory HiveService() => _instance;
  HiveService._();

  Box<String>? _dailyStateBox;
  Box<String>? _focusBox;
  Box<String>? _quickTasksBox;
  Box<String>? _customTasksBox;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    await Hive.initFlutter();
    _dailyStateBox = await Hive.openBox<String>('daily_state');
    _focusBox = await Hive.openBox<String>('todays_focus');
    _quickTasksBox = await Hive.openBox<String>('quick_tasks');
    _customTasksBox = await Hive.openBox<String>('custom_tasks');
    _initialized = true;
  }


  DailyState readDailyState(String dateKey) {
    if (!_initialized) return DailyState.empty(dateKey);
    final raw = _dailyStateBox!.get(dateKey);
    if (raw == null) return DailyState.empty(dateKey);
    try {
      return DailyState.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return DailyState.empty(dateKey);
    }
  }

  Future<void> writeDailyState(DailyState state) async {
    if (!_initialized) return;
    await _dailyStateBox!.put(state.date, jsonEncode(state.toJson()));
  }

  List<DailyState> readAllDailyStates() {
    if (!_initialized || _dailyStateBox == null) return [];
    final states = <DailyState>[];
    for (final key in _dailyStateBox!.keys) {
      final raw = _dailyStateBox!.get(key);
      if (raw != null) {
        try {
          states.add(
            DailyState.fromJson(
              Map<String, dynamic>.from(jsonDecode(raw) as Map),
            ),
          );
        } catch (_) {}
      }
    }
    return states;
  }


  TodaysFocus readTodaysFocus(String dateKey) {
    if (!_initialized) return TodaysFocus.empty(dateKey);
    final raw = _focusBox!.get(dateKey);
    if (raw == null) return TodaysFocus.empty(dateKey);
    try {
      return TodaysFocus.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return TodaysFocus.empty(dateKey);
    }
  }

  Future<void> writeTodaysFocus(TodaysFocus focus) async {
    if (!_initialized) return;
    await _focusBox!.put(focus.date, jsonEncode(focus.toJson()));
  }


  List<QuickTask> readQuickTasks(String dateKey) {
    if (!_initialized) return [];
    final raw = _quickTasksBox!.get(dateKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => QuickTask.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> writeQuickTasks(String dateKey, List<QuickTask> tasks) async {
    if (!_initialized) return;
    await _quickTasksBox!.put(
      dateKey,
      jsonEncode(tasks.map((t) => t.toJson()).toList()),
    );
  }



  List<Task> readCustomTasks() {
    if (!_initialized) return [];
    final raw = _customTasksBox!.get('all_custom_tasks');
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => Task.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> writeCustomTasks(List<Task> tasks) async {
    if (!_initialized) return;
    await _customTasksBox!.put(
      'all_custom_tasks',
      jsonEncode(tasks.map((t) => t.toJson()).toList()),
    );
  }


  Future<void> pruneOldKeys(String currentDateKey) async {
    if (!_initialized) return;
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    for (final box in [_dailyStateBox!, _focusBox!, _quickTasksBox!]) {
      final keysToDelete = box.keys.whereType<String>().where((k) {
        try {
          return DateTime.parse(k).isBefore(cutoff);
        } catch (_) {
          return false;
        }
      }).toList();
      for (final k in keysToDelete) {
        await box.delete(k);
      }
    }
  }

  Future<void> clearAll() async {
    if (!_initialized) return;
    await _dailyStateBox?.clear();
    await _focusBox?.clear();
    await _quickTasksBox?.clear();
    await _customTasksBox?.clear();
  }
}

/// Singleton — import via `hiveService.xxx()`
final hiveService = HiveService();
