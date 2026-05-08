import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/streak.dart';
import '../../main.dart' show deviceId;

// StreakService — manages current_streak + best_streak
// weekStrip: Map<int, bool> where key = weekday index (0=Sun…6=Sat)
// Logic:
//   • allTasksDone=true: mark today's weekday slot, increment streak if
//     yesterday was also complete; otherwise start fresh at 1.
//   • allTasksDone=false: unmark today, decrement streak (floor 0).

class StreakService {
  static final StreakService _instance = StreakService._();
  factory StreakService() => _instance;
  StreakService._();

  SupabaseClient get _db => Supabase.instance.client;

  Future<Streak?> fetchStreak() async {
    try {
      final res = await _db
          .from('streak')
          .select()
          .eq('device_id', deviceId)
          .maybeSingle();
      if (res == null) return null;
      return Streak.fromJson(deviceId, Map<String, dynamic>.from(res));
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
      return null;
    }
  }

  Future<Streak> onTaskToggled({required bool allTasksDone}) async {
    final now = DateTime.now();
    // weekday: Mon=1…Sun=7, we store Sun=0…Sat=6
    final todayIndex = now.weekday % 7; // Mon=1→1, Sun=7→0
    final yesterdayIndex = (todayIndex - 1 + 7) % 7;

    Streak current = await fetchStreak() ?? Streak.empty(deviceId);
    final strip = Map<int, bool>.from(current.weekStrip);

    if (allTasksDone) {
      final alreadyCounted = strip[todayIndex] == true;
      strip[todayIndex] = true;

      int newCurrent;
      if (alreadyCounted) {
        newCurrent = current.currentStreak; // no double-count
      } else if (strip[yesterdayIndex] == true) {
        newCurrent = current.currentStreak + 1; // consecutive
      } else {
        newCurrent = 1; // gap — restart
      }

      final newBest = newCurrent > current.bestStreak
          ? newCurrent
          : current.bestStreak;

      current = Streak(
        deviceId: deviceId,
        weekStrip: strip,
        currentStreak: newCurrent,
        bestStreak: newBest,
      );
    } else {
      // Un-completing — unmark today, decrement if it was counted
      if (strip[todayIndex] == true) {
        strip[todayIndex] = false;
        final newCurrent = (current.currentStreak - 1).clamp(0, 999);
        current = Streak(
          deviceId: deviceId,
          weekStrip: strip,
          currentStreak: newCurrent,
          bestStreak: current.bestStreak,
        );
      }
    }

    _upsertStreak(current);
    return current;
  }

  Future<void> _upsertStreak(Streak streak) async {
    try {
      await _db.from('streak').upsert(streak.toJson(), onConflict: 'device_id');
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
    }
  }

  Future<void> resetStreak() async {
    Streak current = await fetchStreak() ?? Streak.empty(deviceId);
    current = Streak(
      deviceId: deviceId,
      weekStrip: current.weekStrip,
      currentStreak: 0,
      bestStreak: current.bestStreak,
    );
    await _upsertStreak(current);
  }
}

final streakService = StreakService();
