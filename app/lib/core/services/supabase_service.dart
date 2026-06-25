import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../models/daily_state.dart';
import '../models/quick_task.dart';
import '../models/session.dart';
import '../supabase_client.dart';

// SupabaseService — remote persistence
// All rows keyed by deviceId (UUID from SharedPreferences).
// Never call these directly from UI — go through Riverpod providers.
// Call after Hive write to avoid blocking the UI.

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._();
  factory SupabaseService() => _instance;
  SupabaseService._();

  SupabaseClient get _db => supabaseClient;

  Future<void> upsertDailyState(DailyState state, String deviceId) async {
    try {
      await _db.from('daily_state').upsert({
        'device_id': deviceId,
        'date': state.date,
        'task_states': state.taskStates,
        'task_status': state.taskStatus,
        'bonus_states': state.bonusStates,
        if (state.mood != null) 'mood': state.mood,
        'focus_minutes': state.focusMinutes,
        'focus_sessions': state.focusSessions,
        'project_minutes': state.projectMinutes,
        'prayer_states': state.prayerStates,
        'job_applications_count': state.jobApplicationsCount,
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
        taskStatus: _castStringMap(res['task_status']),
        bonusStates: _castBoolMap(res['bonus_states']),
        mood: res['mood']?.toString(),
        focusMinutes:
            int.tryParse(res['focus_minutes']?.toString() ?? '0') ?? 0,
        focusSessions: (res['focus_sessions'] as List<dynamic>? ?? [])
            .map((e) => int.tryParse(e?.toString() ?? '0') ?? 0)
            .toList(),
        projectMinutes: (res['project_minutes'] as Map? ?? {}).map(
          (k, v) =>
              MapEntry(k.toString(), int.tryParse(v?.toString() ?? '0') ?? 0),
        ),
        prayerStates: _castBoolMap(res['prayer_states']),
        jobApplicationsCount:
            int.tryParse(res['job_applications_count']?.toString() ?? '0') ?? 0,
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

  Future<List<Task>> fetchCustomTasks(String deviceId) async {
    try {
      final res = await _db
          .from('custom_tasks')
          .select()
          .eq('device_id', deviceId)
          .order('created_at');

      return (res as List).map((e) {
        final rawTip = e['tip'] as String? ?? '';
        // Decode weekdays from tip if encoded as 'days:1,2,3'
        List<int> weekdays = [];
        String tip = rawTip;
        for (final segment in rawTip.split('|')) {
          if (segment.startsWith('days:')) {
            weekdays = segment
                .substring(5)
                .split(',')
                .map((s) => int.tryParse(s.trim()))
                .whereType<int>()
                .toList();
            tip = rawTip.replaceFirst('|$segment', '').replaceFirst('$segment|', '');
          }
        }
        StateOfMind? som;
        if (e['state_of_mind'] != null) {
          som = StateOfMind.values.firstWhere(
            (val) => val.name == e['state_of_mind'],
            orElse: () => StateOfMind.flow,
          );
        }
        return Task(
          id: e['id'],
          sessionId: e['session_id'],
          title: e['title'],
          time: e['time'] ?? '',
          durationMinutes: e['duration_minutes'] ?? 15,
          tip: tip,
          isBreak: e['is_break'] ?? false,
          hasSessionTimer: e['has_session_timer'] ?? false,
          iconName: e['icon_name'] ?? 'star',
          weekdays: weekdays,
          stateOfMind: som,
          isUrgent: e['is_urgent'] ?? false,
          priority: e['priority'],
          createdAt: e['created_at'] != null ? DateTime.tryParse(e['created_at'] as String) : null,
        );
      }).toList();
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
      return [];
    }
  }

  Future<void> upsertCustomTask(Task task, String deviceId) async {
    try {
      // Encode weekdays into tip field to avoid schema change.
      // Format tip: 'key_task:true|days:1,2,3|Custom task'
      String tipWithDays = task.tip;
      if (task.weekdays.isNotEmpty) {
        // Inject days segment after key_task prefix
        final days = 'days:${task.weekdays.join(',')}';
        if (tipWithDays.contains('|')) {
          final parts = tipWithDays.split('|');
          // Remove any old days: segment then re-insert
          final cleaned = parts.where((p) => !p.startsWith('days:')).toList();
          cleaned.insert(1, days);
          tipWithDays = cleaned.join('|');
        } else {
          tipWithDays = '$tipWithDays|$days';
        }
      }
      await _db.from('custom_tasks').upsert({
        'id': task.id,
        'device_id': deviceId,
        'session_id': task.sessionId,
        'title': task.title,
        'time': task.time,
        'duration_minutes': task.durationMinutes,
        'tip': tipWithDays,
        'is_break': task.isBreak,
        'has_session_timer': task.hasSessionTimer,
        'icon_name': task.iconName,
        'state_of_mind': task.stateOfMind?.name,
        'is_urgent': task.isUrgent,
        'priority': task.priority,
        'created_at': task.createdAt?.toIso8601String(),
      });
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
    }
  }

  Future<void> deleteCustomTask(String taskId) async {
    try {
      await _db.from('custom_tasks').delete().eq('id', taskId);
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
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
          .select('date, task_states, task_status')
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
      await _db
          .from('quick_tasks')
          .update({'done': false})
          .eq('device_id', deviceId);
      await _db.from('stats_history').delete().eq('device_id', deviceId);
      await _db.from('streak').delete().eq('device_id', deviceId);
      await _db.from('custom_tasks').delete().eq('device_id', deviceId);

      // Seed a fresh empty streak so fetchStreak() has a valid record going forward
      await _db.from('streak').upsert({
        'device_id': deviceId,
        'week_strip': {},
        'current_streak': 0,
        'best_streak': 0,
      });
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

  Map<String, String> _castStringMap(dynamic raw) {
    if (raw == null) return {};
    return (raw as Map).map(
      (k, v) => MapEntry(k.toString(), v?.toString() ?? 'none'),
    );
  }

  Future<Map<String, dynamic>?> fetchProfile(String uid) async {
    try {
      final res = await _db
          .from('profiles')
          .select()
          .eq('id', uid)
          .maybeSingle();
      return res;
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
      return null;
    }
  }

  Future<void> updateProfile(String uid, String fullName, String? avatarUrl) async {
    try {
      await _db.from('profiles').update({
        'full_name': fullName,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', uid);
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
      rethrow;
    }
  }

  Future<String> uploadAvatar(
    String uid,
    List<int> bytes,
    String extension,
    String mimeType,
  ) async {
    try {
      // Store under uid/ folder so storage policies (which check foldername) work correctly
      final fileName = '$uid/$uid-${DateTime.now().millisecondsSinceEpoch}.$extension';
      
      // Upload using storage API
      await _db.storage.from('avatars').uploadBinary(
        fileName,
        Uint8List.fromList(bytes),
        fileOptions: FileOptions(
          contentType: mimeType,
          cacheControl: '3600',
          upsert: true,
        ),
      );
      
      // Get public URL
      final publicUrl = _db.storage.from('avatars').getPublicUrl(fileName);
      return publicUrl;
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
      rethrow;
    }
  }
}

/// Singleton — import via `supabaseService.xxx()`
final supabaseService = SupabaseService();
