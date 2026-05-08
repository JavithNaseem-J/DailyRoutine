import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../models/daily_state.dart';
import '../models/quick_task.dart';

// SupabaseService — remote persistence
// All rows keyed by deviceId (UUID from SharedPreferences).
// Never call these directly from UI — go through Riverpod providers.
// Call after Hive write to avoid blocking the UI.

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._();
  factory SupabaseService() => _instance;
  SupabaseService._();

  SupabaseClient get _db => Supabase.instance.client;


  Future<void> upsertDailyState(DailyState state, String deviceId) async {
    try {
      await _db.from('daily_state').upsert({
        'device_id': deviceId,
        'date': state.date,
        'task_states': state.taskStates,
        'bonus_states': state.bonusStates,
        if (state.mood != null) 'mood': state.mood,
        'focus_minutes': state.focusMinutes,
        'project_minutes': state.projectMinutes,
        'prayer_states': state.prayerStates,
      }, onConflict: 'device_id, date');
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
    }
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
        focusMinutes: res['focus_minutes'] as int? ?? 0,
        projectMinutes: (res['project_minutes'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, (v as num).toInt())),
        prayerStates: _castBoolMap(res['prayer_states']),
      );
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
      return null;
    }
  }


  Future<void> upsertQuickTask(QuickTask task, String deviceId) async {
    try {
      await _db.from('quick_tasks').upsert({
        'id': task.id,
        'device_id': deviceId,
        'date': task.date,
        'title': task.title,
        if (task.time != null) 'time': task.time,
        'done': task.done,
        'archived': task.archived,
        'is_urgent': task.isUrgent,
        'is_important': task.isImportant,
        if (task.priority != null) 'priority': task.priority,
        if (task.deadline != null) 'deadline': task.deadline,
        if (task.delegatee != null) 'delegatee': task.delegatee,
      });
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
    }
  }

  Future<void> deleteQuickTask(String taskId) async {
    try {
      await _db.from('quick_tasks').delete().eq('id', taskId);
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
    }
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
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
      return [];
    }
  }




  Future<void> upsertStatsHistory(
    String dateKey,
    int completionPct,
    String deviceId,
  ) async {
    try {
      await _db.from('stats_history').upsert({
        'device_id': deviceId,
        'date': dateKey,
        'completion_pct': completionPct,
      }, onConflict: 'device_id, date');
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
    }
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
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
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
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
      return [];
    }
  }

  Future<void> resetAllData(String deviceId) async {
    try {
      await _db.from('daily_state').delete().eq('device_id', deviceId);
      await _db.from('quick_tasks').delete().eq('device_id', deviceId);
      await _db.from('stats_history').delete().eq('device_id', deviceId);
      await _db.from('streak').delete().eq('device_id', deviceId);
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
    }
  }


  // BUG-018 fix: safe cast handles both bool and int (0/1) from Postgres
  Map<String, bool> _castBoolMap(dynamic raw) {
    if (raw == null) return {};
    return (raw as Map).map(
      (k, v) => MapEntry(k.toString(), v == true || v == 1),
    );
  }
}

/// Singleton — import via `supabaseService.xxx()`
final supabaseService = SupabaseService();
