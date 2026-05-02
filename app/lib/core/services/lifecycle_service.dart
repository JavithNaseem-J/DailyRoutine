import 'package:flutter/material.dart';
import '../services/date_service.dart';
import '../services/hive_service.dart';
import '../../main.dart' show sharedPrefs;

// ─────────────────────────────────────────────────────────────────────────────
// LifecycleService — handles midnight date rollover
//
// On every app resume (AppLifecycleState.resumed):
//   1. Compare stored date key to today
//   2. If different → archive old quick tasks, prune old Hive keys
//   3. Save new date key to SharedPreferences
//
// Usage: wrap your top-level app widget with LifecycleObserver
// ─────────────────────────────────────────────────────────────────────────────

class LifecycleService extends WidgetsBindingObserver {
  static final LifecycleService _instance = LifecycleService._();
  factory LifecycleService() => _instance;
  LifecycleService._();

  static const _storedDateKey = 'lastActiveDate';

  void init() {
    WidgetsBinding.instance.addObserver(this);
    _checkDateRollover();
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkDateRollover();
    }
  }

  Future<void> _checkDateRollover() async {
    final stored = sharedPrefs.getString(_storedDateKey);
    final today = dateService.todayKey();

    if (stored != null && stored != today) {
      // Day has changed — archive yesterday's quick tasks
      await _rollover(oldDateKey: stored);
    }

    // Update stored date
    await sharedPrefs.setString(_storedDateKey, today);
  }

  Future<void> _rollover({required String oldDateKey}) async {
    // Quick tasks are now global, so we don't archive them.

    // 3. Prune Hive boxes older than 30 days
    await hiveService.pruneOldKeys(dateService.todayKey());
  }
}

final lifecycleService = LifecycleService();
