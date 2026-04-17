import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/daily_state.dart';
import '../../core/models/quick_task.dart';
import '../../core/models/todays_focus.dart';
import '../../core/services/date_service.dart';
import '../../core/services/hive_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/streak_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../main.dart' show deviceId, sharedPrefs;

// ─────────────────────────────────────────────────────────────────────────────
// Settings Screen — Phase 4.5
// ─────────────────────────────────────────────────────────────────────────────

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _isResetting = false;
  final TextEditingController _resetController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _notificationsEnabled =
        sharedPrefs.getBool('notificationsEnabled') ?? true;
  }

  @override
  void dispose() {
    _resetController.dispose();
    super.dispose();
  }

  // ── Toggle notifications ───────────────────────────────────────────
  Future<void> _toggleNotifications(bool value) async {
    setState(() => _notificationsEnabled = value);
    await sharedPrefs.setBool('notificationsEnabled', value);
    if (value) {
      await notificationService.scheduleSessionNotifications(
          notificationsEnabled: true);
    } else {
      await notificationService.cancelAll();
    }
  }

  // ── Reset today ────────────────────────────────────────────────────
  Future<void> _resetToday() async {
    final confirm = await _showConfirm(
      title: 'Reset Today',
      message:
          'This will clear all task completions for today. Continue?',
    );
    if (!confirm) return;

    final today = dateService.todayKey();
    final empty = DailyState.empty(today);
    await hiveService.writeDailyState(empty);
    supabaseService.upsertDailyState(empty, deviceId).catchError((_) {});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Today reset.')),
      );
    }
  }

  // ── Reset streak ───────────────────────────────────────────────────
  Future<void> _resetStreak() async {
    final confirm = await _showConfirm(
      title: 'Reset Streak',
      message: 'This will reset your streak to 0. Continue?',
    );
    if (!confirm) return;

    await streakService.onTaskToggled(allTasksDone: false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Streak reset.')),
      );
    }
  }

  // ── Reset ALL (requires typed "RESET") ────────────────────────────
  Future<void> _showResetAllDialog() async {
    _resetController.clear();
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: AppColors.cardSurface,
          title: Text('Reset Everything',
              style: AppTypography.body(
                  size: 16,
                  weight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This clears ALL task history, streak, focus, and quick '
                'tasks.\nType RESET to confirm.',
                style: AppTypography.body(
                    size: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _resetController,
                autofocus: true,
                onChanged: (_) => setDlg(() {}),
                style: AppTypography.mono(
                    size: 14,
                    weight: FontWeight.w600,
                    color: const Color(0xFFD44060)),
                decoration: InputDecoration(
                  hintText: 'Type RESET',
                  hintStyle: AppTypography.body(
                      size: 13, color: AppColors.textMuted),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: AppTypography.body(
                      size: 13, color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: _resetController.text == 'RESET'
                  ? () async {
                      Navigator.pop(ctx);
                      await _performResetAll();
                    }
                  : null,
              child: Text('Reset',
                  style: AppTypography.body(
                      size: 13,
                      weight: FontWeight.w600,
                      color: _resetController.text == 'RESET'
                          ? const Color(0xFFD44060)
                          : AppColors.textMuted)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performResetAll() async {
    setState(() => _isResetting = true);
    final today = dateService.todayKey();

    await hiveService.writeDailyState(DailyState.empty(today));
    await hiveService.writeQuickTasks(today, <QuickTask>[]);
    await hiveService.writeTodaysFocus(TodaysFocus.empty(today));

    supabaseService
        .upsertDailyState(DailyState.empty(today), deviceId)
        .catchError((_) {});

    setState(() => _isResetting = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All data reset.')),
      );
    }
  }

  Future<bool> _showConfirm(
      {required String title, required String message}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardSurface,
        title: Text(title,
            style: AppTypography.body(
                size: 16,
                weight: FontWeight.w600,
                color: AppColors.textPrimary)),
        content: Text(message,
            style: AppTypography.body(
                size: 13, color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: AppTypography.body(
                    size: 13, color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Confirm',
                style: AppTypography.body(
                    size: 13,
                    weight: FontWeight.w600,
                    color: AppColors.primary)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: const BackButton(),
        title: Text('Settings',
            style:
                AppTypography.screenTitle(color: AppColors.textPrimary)),
        iconTheme:
            const IconThemeData(color: AppColors.textPrimary),
      ),
      body: _isResetting
          ? const Center(
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // ── Notifications ──────────────────────────────────
                const _SectionHeader(title: 'Notifications'),
                _SettingsTile(
                  icon: Icons.notifications_active_outlined,
                  title: 'Session reminders',
                  subtitle: '15 min before each session',
                  trailing: Switch(
                    value: _notificationsEnabled,
                    activeThumbColor: AppColors.complete,
                    onChanged: _toggleNotifications,
                  ),
                ),
                _SettingsTile(
                  icon: Icons.mosque_outlined,
                  title: 'Prayer alerts',
                  subtitle: 'Fajr + Asr — 10 min warning',
                  trailing: Switch(
                    value: _notificationsEnabled,
                    activeThumbColor: AppColors.complete,
                    onChanged: _toggleNotifications,
                  ),
                ),

                const SizedBox(height: 24),

                // ── Prayer Times ───────────────────────────────────
                const _SectionHeader(title: 'Prayer Times'),
                const _SettingsTile(
                  icon: Icons.my_location_outlined,
                  title: 'Location',
                  subtitle: 'Dubai — 25.2048°N, 55.2708°E',
                  trailing: Icon(Icons.lock_outline,
                      size: 16, color: AppColors.textMuted),
                ),
                const _SettingsTile(
                  icon: Icons.calculate_outlined,
                  title: 'Calculation method',
                  subtitle: 'Karachi (UAE-equivalent)',
                  trailing: Icon(Icons.lock_outline,
                      size: 16, color: AppColors.textMuted),
                ),

                const SizedBox(height: 24),

                // ── Data & Reset ───────────────────────────────────
                const _SectionHeader(title: 'Data & Reset'),
                _SettingsTile(
                  icon: Icons.refresh_rounded,
                  title: 'Reset today',
                  subtitle: 'Clear all task completions for today',
                  onTap: _resetToday,
                ),
                _SettingsTile(
                  icon: Icons.local_fire_department_outlined,
                  title: 'Reset streak',
                  subtitle: 'Set streak back to 0',
                  onTap: _resetStreak,
                ),
                _SettingsTile(
                  icon: Icons.delete_outline,
                  title: 'Reset everything',
                  subtitle: 'Requires typing "RESET"',
                  titleColor: const Color(0xFFD44060),
                  onTap: _showResetAllDialog,
                ),

                const SizedBox(height: 24),

                // ── Skip Recovery ──────────────────────────────────
                const _SectionHeader(title: 'Skip Recovery Rules'),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.cardSurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _RuleRow(
                        label: 'Missed 1 task',
                        value: 'Do it in the next free slot',
                      ),
                      _RuleRow(
                        label: 'Missed full session',
                        value:
                            'Add "catch-up" tasks in next session',
                      ),
                      _RuleRow(
                        label: 'Missed full day',
                        value:
                            'Streak resets — start fresh tomorrow',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                Center(
                  child: Text('Daily Routine v1.0.0',
                      style: AppTypography.label(
                          color: AppColors.textMuted)),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text('Built for Naseem · Dubai',
                      style: AppTypography.mono(
                          size: 10, color: AppColors.textMuted)),
                ),

                const SizedBox(height: 20),
              ],
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section Header
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: AppTypography.mono(
            size: 10,
            weight: FontWeight.w600,
            color: AppColors.textMuted),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Settings Tile
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.titleColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTypography.body(
                        size: 14,
                        weight: FontWeight.w500,
                        color: titleColor ?? AppColors.textPrimary,
                      )),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: AppTypography.label(
                          color: AppColors.textMuted)),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ] else if (onTap != null)
              const Icon(Icons.chevron_right,
                  size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Rule Row
// ─────────────────────────────────────────────────────────────────────────────

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.arrow_right_rounded,
              size: 18, color: AppColors.textMuted),
          const SizedBox(width: 4),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: AppTypography.body(
                        size: 12,
                        weight: FontWeight.w600,
                        color: AppColors.textPrimary),
                  ),
                  TextSpan(
                    text: value,
                    style: AppTypography.body(
                        size: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
