import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/daily_state.dart';
import '../models/quick_task.dart';
import '../models/todays_focus.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SupabaseService — remote persistence
//
// All rows keyed by deviceId (UUID from SharedPreferences).
// Never call these directly from UI — go through Riverpod providers.
// Call after Hive write to avoid blocking the UI.
// ─────────────────────────────────────────────────────────────────────────────

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._();
  factory SupabaseService() => _instance;
  SupabaseService._();

  SupabaseClient get _db => Supabase.instance.client;

  // ── DailyState ─────────────────────────────────────────────────────

  Future<void> upsertDailyState(DailyState state, String deviceId) async {
    await _db.from('daily_state').upsert({
      'device_id': deviceId,
      'date': state.date,
      'task_states': state.taskStates,
      'bonus_states': state.bonusStates,
      if (state.mood != null) 'mood': state.mood,
    }, onConflict: 'device_id, date');
  }

  Future<DailyState?> fetchDailyState(String dateKey, String deviceId) async {
    try {
      final res = await _db
          .from('daily_state')
          .select()
          .eq('device_id', deviceId)
          .eq('date', dateKey)
          .maybeSingle();

      if (res == null) return null;

      return DailyState(
        date: res['date'] as String,
        taskStates: _castBoolMap(res['task_states']),
        bonusStates: _castBoolMap(res['bonus_states']),
        mood: res['mood'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  // ── TodaysFocus ────────────────────────────────────────────────────

  Future<void> upsertTodaysFocus(TodaysFocus focus, String deviceId) async {
    await _db.from('todays_focus').upsert({
      'device_id': deviceId,
      'date': focus.date,
      'session1': focus.session1,
      'session2': focus.session2,
      'session3': focus.session3,
    }, onConflict: 'device_id, date');
  }

  Future<TodaysFocus?> fetchTodaysFocus(String dateKey, String deviceId) async {
    try {
      final res = await _db
          .from('todays_focus')
          .select()
          .eq('device_id', deviceId)
          .eq('date', dateKey)
          .maybeSingle();

      if (res == null) return null;
      return TodaysFocus.fromJson(Map<String, dynamic>.from(res));
    } catch (_) {
      return null;
    }
  }

  // ── QuickTasks ─────────────────────────────────────────────────────

  Future<void> upsertQuickTask(QuickTask task, String deviceId) async {
    await _db.from('quick_tasks').upsert({
      'id': task.id,
      'device_id': deviceId,
      'date': task.date,
      'title': task.title,
      if (task.time != null) 'time': task.time,
      'done': task.done,
      'archived': task.archived,
    });
  }

  Future<void> deleteQuickTask(String taskId) async {
    await _db.from('quick_tasks').delete().eq('id', taskId);
  }

  Future<List<QuickTask>> fetchQuickTasks(
    String dateKey,
    String deviceId,
  ) async {
    try {
      final res = await _db
          .from('quick_tasks')
          .select()
          .eq('device_id', deviceId)
          .eq('date', dateKey)
          .eq('archived', false)
          .order('created_at');

      return (res as List)
          .map((e) => QuickTask.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> archiveOldQuickTasks(String oldDateKey, String deviceId) async {
    await _db
        .from('quick_tasks')
        .update({'archived': true})
        .eq('device_id', deviceId)
        .eq('date', oldDateKey);
  }

  // ── StatsHistory ───────────────────────────────────────────────────

  Future<void> upsertStatsHistory(
    String dateKey,
    int completionPct,
    String deviceId,
  ) async {
    await _db.from('stats_history').upsert({
      'device_id': deviceId,
      'date': dateKey,
      'completion_pct': completionPct,
    }, onConflict: 'device_id, date');
  }

  Future<List<Map<String, dynamic>>> fetchStatsHistory(
    int days,
    String deviceId,
  ) async {
    try {
      final from = DateTime.now().subtract(Duration(days: days));
      final res = await _db
          .from('stats_history')
          .select('date, completion_pct')
          .eq('device_id', deviceId)
          .gte('date', from.toIso8601String().split('T').first)
          .order('date');
      return List<Map<String, dynamic>>.from(res);
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetch30DayTaskHistory(
    String deviceId,
  ) async {
    try {
      final from = DateTime.now().subtract(const Duration(days: 30));
      final res = await _db
          .from('daily_state')
          .select('date, task_states')
          .eq('device_id', deviceId)
          .gte('date', from.toIso8601String().split('T').first)
          .order('date');
      return List<Map<String, dynamic>>.from(res);
    } catch (_) {
      return [];
    }
  }

  // ── Heatmap ────────────────────────────────────────────────────────

  Future<void> upsertHeatmap(String dateKey, int value, String deviceId) async {
    await _db.from('heatmap').upsert({
      'device_id': deviceId,
      'date': dateKey,
      'value': value,
    }, onConflict: 'device_id, date');
  }

  Future<List<Map<String, dynamic>>> fetchHeatmap(String deviceId) async {
    try {
      final from = DateTime.now().subtract(const Duration(days: 28));
      final res = await _db
          .from('heatmap')
          .select('date, value')
          .eq('device_id', deviceId)
          .gte('date', from.toIso8601String().split('T').first)
          .order('date');
      return List<Map<String, dynamic>>.from(res);
    } catch (_) {
      return [];
    }
  }

  // ── Helper ─────────────────────────────────────────────────────────

  Map<String, bool> _castBoolMap(dynamic raw) {
    if (raw == null) return {};
    return (raw as Map).map((k, v) => MapEntry(k.toString(), v as bool));
  }
}

/// Singleton — import via `supabaseService.xxx()`
final supabaseService = SupabaseService();
