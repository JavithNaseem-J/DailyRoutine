import '../models/daily_state.dart';

class GamificationService {
  /// Calculate Discipline Score based on the current DailyState.
  /// Points breakdown:
  /// - Tasks: 40%
  /// - Focus: 30%
  /// - Habits: 20%
  /// - Streak: 10%
  static int calculateDisciplineScore(
    DailyState state, {
    int currentStreak = 0,
    int focusTargetMinutes = 120, // default target
    required int totalScheduledTasks,
  }) {
    double taskPoints = _calculateTaskPoints(state, totalScheduledTasks);
    double focusPoints = _calculateFocusPoints(state, focusTargetMinutes);
    double habitPoints = _calculateHabitPoints(state);
    double streakPoints = _calculateStreakPoints(currentStreak);

    return (taskPoints + focusPoints + habitPoints + streakPoints)
        .clamp(0, 100)
        .round();
  }

  static double _calculateTaskPoints(
    DailyState state,
    int totalScheduledTasks,
  ) {
    int skippedTasks = state.taskStatus.values
        .where((status) => status == 'skipped')
        .length;
    int completedTasks = state.taskStates.values
        .where((done) => done == true)
        .length;

    int totalValidTasks = totalScheduledTasks - skippedTasks;

    if (totalScheduledTasks == 0) return 0.0;
    if (totalValidTasks <= 0) return 0.0;

    return (completedTasks / totalValidTasks).clamp(0.0, 1.0) * 40.0;
  }

  static double _calculateFocusPoints(DailyState state, int target) {
    if (target <= 0) return 30.0;
    double ratio = state.focusMinutes / target;
    return (ratio.clamp(0.0, 1.0)) * 30.0;
  }

  static double _calculateHabitPoints(DailyState state) {
    int totalPrayers = 5;
    int completedPrayers = state.prayerStates.values
        .where((done) => done)
        .length;
    return (completedPrayers / totalPrayers) * 20.0;
  }

  static double _calculateStreakPoints(int streak) {
    // Max streak points reached at 30 days
    double ratio = streak / 30.0;
    return (ratio.clamp(0.0, 1.0)) * 10.0;
  }

  static String getProductivityLevel(int score) {
    if (score >= 91) return 'Elite';
    if (score >= 76) return 'Disciplined';
    if (score >= 51) return 'Focused';
    if (score >= 31) return 'Consistent';
    return 'Beginner';
  }
}
