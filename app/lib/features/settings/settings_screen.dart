import 'package:flutter/cupertino.dart';
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
  bool _sessionReminders = true;
  bool _prayerAlerts = true;
  bool _isResetting = false;
  final TextEditingController _resetController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _sessionReminders = sharedPrefs.getBool('sessionReminders') ?? true;
    _prayerAlerts = sharedPrefs.getBool('prayerAlerts') ?? true;
  }

  @override
  void dispose() {
    _resetController.dispose();
    super.dispose();
  }

  Future<void> _toggleSessionReminders(bool value) async {
    setState(() => _sessionReminders = value);
    await sharedPrefs.setBool('sessionReminders', value);
    await notificationService.scheduleSessionNotifications(
      sessionRemindersEnabled: _sessionReminders,
      prayerAlertsEnabled: _prayerAlerts,
    );
  }

  Future<void> _togglePrayerAlerts(bool value) async {
    setState(() => _prayerAlerts = value);
    await sharedPrefs.setBool('prayerAlerts', value);
    await notificationService.scheduleSessionNotifications(
      sessionRemindersEnabled: _sessionReminders,
      prayerAlertsEnabled: _prayerAlerts,
    );
  }

  // ── Reset today ────────────────────────────────────────────────────
  Future<void> _resetToday() async {
    final confirm = await _showConfirm(
      title: 'Reset Today',
      message: 'This will clear all task completions for today. Continue?',
    );
    if (!confirm) return;

    final today = dateService.todayKey();
    final empty = DailyState.empty(today);
    await hiveService.writeDailyState(empty);
    supabaseService.upsertDailyState(empty, deviceId).catchError((_) {});

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Today reset.')));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Streak reset.')));
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
          title: Text(
            'Reset Everything',
            style: AppTypography.body(
              size: 16,
              weight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This clears ALL task history, streak, focus, and quick '
                'tasks.\nType RESET to confirm.',
                style: AppTypography.body(
                  size: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: _resetController,
                autofocus: true,
                onChanged: (_) => setDlg(() {}),
                style: AppTypography.mono(
                  size: 14,
                  weight: FontWeight.w600,
                  color: Color(0xFFD44060),
                ),
                decoration: InputDecoration(
                  hintText: 'Type RESET',
                  hintStyle: AppTypography.body(
                    size: 13,
                    color: AppColors.textMuted,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: AppTypography.body(
                  size: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: _resetController.text == 'RESET'
                  ? () async {
                      Navigator.pop(ctx);
                      await _performResetAll();
                    }
                  : null,
              child: Text(
                'Reset',
                style: AppTypography.body(
                  size: 13,
                  weight: FontWeight.w600,
                  color: _resetController.text == 'RESET'
                      ? Color(0xFFD44060)
                      : AppColors.textMuted,
                ),
              ),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('All data reset.')));
    }
  }

  Future<bool> _showConfirm({
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardSurface,
        title: Text(
          title,
          style: AppTypography.body(
            size: 16,
            weight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          message,
          style: AppTypography.body(size: 13, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: AppTypography.body(
                size: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Confirm',
              style: AppTypography.body(
                size: 13,
                weight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
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
        title: Text(
          'Settings',
          style: AppTypography.screenTitle(color: AppColors.textPrimary),
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      body: _isResetting
          ? Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [


                // ── Notifications ──────────────────────────────────
                const _SectionHeader(title: 'Notifications'),
                _SettingsTile(
                  icon: Icons.notifications_active_outlined,
                  title: 'Session reminders',
                  subtitle: '15 min before each session',
                  trailing: CupertinoSwitch(
                    value: _sessionReminders,
                    activeTrackColor: AppColors.complete,
                    onChanged: _toggleSessionReminders,
                  ),
                ),
                _SettingsTile(
                  icon: Icons.mosque_outlined,
                  title: 'Prayer alerts',
                  subtitle: 'Fajr + Asr — 10 min warning',
                  trailing: CupertinoSwitch(
                    value: _prayerAlerts,
                    activeTrackColor: AppColors.complete,
                    onChanged: _togglePrayerAlerts,
                  ),
                ),

                SizedBox(height: 24),

                // ── Prayer Times ───────────────────────────────────
                const _SectionHeader(title: 'Prayer Times'),
                _SettingsTile(
                  icon: Icons.my_location_outlined,
                  title: 'Location',
                  subtitle: 'Dubai — 25.2048°N, 55.2708°E',
                  trailing: Icon(
                    Icons.lock_outline,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                ),
                _SettingsTile(
                  icon: Icons.calculate_outlined,
                  title: 'Calculation method',
                  subtitle: 'Karachi (UAE-equivalent)',
                  trailing: Icon(
                    Icons.lock_outline,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                ),

                SizedBox(height: 24),

                // ── Data & Reset ───────────────────────────────────
                const _SectionHeader(title: 'Data & Reset'),
                _SettingsTile(
                  icon: Icons.refresh_rounded,
                  title: 'Reset today',
                  onTap: _resetToday,
                ),
                _SettingsTile(
                  icon: Icons.local_fire_department_outlined,
                  title: 'Reset streak',
                  onTap: _resetStreak,
                ),
                _SettingsTile(
                  icon: Icons.delete_outline,
                  title: 'Reset everything',
                  titleColor: Color(0xFFD44060),
                  onTap: _showResetAllDialog,
                ),

                SizedBox(height: 52),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Yawmi',
                      style: AppTypography.body(
                        size: 15,
                        weight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Version 1.0.0',
                      style: AppTypography.mono(
                        size: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                    SizedBox(height: 32),
                    Text(
                      'Designed & Engineered by Naseem',
                      style: AppTypography.body(
                        size: 12,
                        weight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '© 2026 Naseem. All rights reserved.',
                      style: AppTypography.body(
                        size: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 32),
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
          color: AppColors.textMuted,
        ),
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
    this.subtitle,
    this.trailing,
    this.onTap,
    this.titleColor,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
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
                  Text(
                    title,
                    style: AppTypography.body(
                      size: 14,
                      weight: FontWeight.w500,
                      color: titleColor ?? AppColors.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: AppTypography.label(color: AppColors.textMuted),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ] else if (onTap != null)
              Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors.textMuted,
              ),
          ],
        ),
      ),
    );
  }
}

