import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
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
import 'package:url_launcher/url_launcher.dart';
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
  String _prayerMode = 'auto';
  String _prayerLocation = 'Dubai';
  bool _isResetting = false;
  bool _isLocating = false;

  final TextEditingController _resetController = TextEditingController();

  Map<String, String> _manualTimes = {
    'fajr': '05:00',
    'dhuhr': '12:30',
    'asr': '15:45',
    'maghrib': '18:15',
    'isha': '19:30',
  };

  @override
  void initState() {
    super.initState();
    _sessionReminders = sharedPrefs.getBool('sessionReminders') ?? true;
    _prayerAlerts = sharedPrefs.getBool('prayerAlerts') ?? true;
    _prayerMode = sharedPrefs.getString('prayer_mode') ?? 'auto';
    _prayerLocation = sharedPrefs.getString('prayer_location') ?? 'Dubai';

    _manualTimes = {
      'fajr': sharedPrefs.getString('manual_fajr') ?? '05:00',
      'dhuhr': sharedPrefs.getString('manual_dhuhr') ?? '12:30',
      'asr': sharedPrefs.getString('manual_asr') ?? '15:45',
      'maghrib': sharedPrefs.getString('manual_maghrib') ?? '18:15',
      'isha': sharedPrefs.getString('manual_isha') ?? '19:30',
    };
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

  // ── Change Location (GPS) ───────────────────────────────────────────
  Future<void> _changeLocation() async {
    setState(() => _isLocating = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied.');
      } 

      Position position = await Geolocator.getCurrentPosition();
      
      await sharedPrefs.setDouble('prayer_lat', position.latitude);
      await sharedPrefs.setDouble('prayer_lng', position.longitude);

      List<Placemark> placemarks = [];
      try {
        placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      } catch (e) {
        // Geocoding may not be supported on this platform (e.g., Web)
      }
      
      String newLocation = 'Unknown Location';
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final city = place.locality ?? place.subAdministrativeArea ?? place.administrativeArea ?? '';
        final country = place.country ?? '';
        newLocation = city.isNotEmpty && country.isNotEmpty ? '$city, $country' : city.isNotEmpty ? city : country;
        if (newLocation.isEmpty) newLocation = 'GPS Location';
      }

      setState(() {
        _prayerLocation = newLocation;
      });
      await sharedPrefs.setString('prayer_location', newLocation);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location updated: $newLocation')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}')),
        );
      }
    } finally {
      setState(() => _isLocating = false);
    }
  }

  Future<void> _pickManualTime(String key) async {
    final parts = _manualTimes[key]!.split(':');
    TimeOfDay initial = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 0,
      minute: parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
    );

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );

    if (picked != null) {
      final h = picked.hour.toString().padLeft(2, '0');
      final m = picked.minute.toString().padLeft(2, '0');
      final formatted = '$h:$m';
      
      setState(() {
        _manualTimes[key] = formatted;
      });
      await sharedPrefs.setString('manual_$key', formatted);
    }
  }

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
                  subtitle: '10 mins warning for all prayers',
                  trailing: CupertinoSwitch(
                    value: _prayerAlerts,
                    activeTrackColor: AppColors.complete,
                    onChanged: _togglePrayerAlerts,
                  ),
                ),

                SizedBox(height: 24),

                // ── Prayer Times ───────────────────────────────────
                const _SectionHeader(title: 'Prayer Times'),
                Row(
                  children: [
                    Expanded(
                      child: CupertinoSegmentedControl<String>(
                        groupValue: _prayerMode,
                        children: {
                          'auto': Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Automatic', style: AppTypography.body(size: 13, color: _prayerMode == 'auto' ? Colors.white : AppColors.primary))),
                          'manual': Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Manual', style: AppTypography.body(size: 13, color: _prayerMode == 'manual' ? Colors.white : AppColors.primary))),
                        },
                        onValueChanged: (val) async {
                          setState(() => _prayerMode = val);
                          await sharedPrefs.setString('prayer_mode', val);
                        },
                        selectedColor: AppColors.primary,
                        borderColor: AppColors.primary,
                        unselectedColor: Colors.transparent,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                if (_prayerMode == 'auto') ...[
                  _SettingsTile(
                    icon: Icons.my_location_outlined,
                    title: 'Location',
                    subtitle: _prayerLocation,
                    onTap: _isLocating ? null : _changeLocation,
                    trailing: _isLocating 
                        ? SizedBox(
                            width: 16, 
                            height: 16, 
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)
                          )
                        : Icon(
                            Icons.chevron_right,
                            size: 16,
                            color: AppColors.textMuted,
                          ),
                  ),
                  _SettingsTile(
                    icon: Icons.calculate_outlined,
                    title: 'Calculation method',
                    subtitle: 'Muslim World League (Auto)',
                    trailing: Icon(
                      Icons.lock_outline,
                      size: 16,
                      color: AppColors.textMuted,
                    ),
                  ),
                ] else ...[
                  _SettingsTile(icon: Icons.wb_twilight, title: 'Fajr', trailing: Text(_manualTimes['fajr']!, style: AppTypography.mono(color: AppColors.primary)), onTap: () => _pickManualTime('fajr')),
                  _SettingsTile(icon: Icons.wb_sunny_rounded, title: 'Dhuhr', trailing: Text(_manualTimes['dhuhr']!, style: AppTypography.mono(color: AppColors.primary)), onTap: () => _pickManualTime('dhuhr')),
                  _SettingsTile(icon: Icons.wb_sunny_outlined, title: 'Asr', trailing: Text(_manualTimes['asr']!, style: AppTypography.mono(color: AppColors.primary)), onTap: () => _pickManualTime('asr')),
                  _SettingsTile(icon: Icons.cloud_outlined, title: 'Maghrib', trailing: Text(_manualTimes['maghrib']!, style: AppTypography.mono(color: AppColors.primary)), onTap: () => _pickManualTime('maghrib')),
                  _SettingsTile(icon: Icons.nights_stay_outlined, title: 'Isha', trailing: Text(_manualTimes['isha']!, style: AppTypography.mono(color: AppColors.primary)), onTap: () => _pickManualTime('isha')),
                ],

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
                    GestureDetector(
                      onTap: () async {
                        final uri = Uri.parse('https://javithnaseem.netlify.app');
                        try {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } catch (_) {
                          try {
                            await launchUrl(uri, mode: LaunchMode.platformDefault);
                          } catch (_) {}
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.code_rounded,
                              size: 14,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Designed & Engineered by Naseem',
                              style: AppTypography.body(
                                size: 12,
                                weight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.open_in_new_rounded,
                              size: 12,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
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

