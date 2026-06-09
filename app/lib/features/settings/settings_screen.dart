import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../core/models/daily_state.dart';
import '../../core/services/date_service.dart';
import '../../core/services/hive_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/streak_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/supabase_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import '../sessions/providers/sessions_provider.dart';
import '../../main.dart' show deviceId, sharedPrefs;
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';



// Settings Screen — Phase 4.5

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

  // Profile fields
  String _profileName = '';
  String _profileEmail = '';
  String _profileAvatarUrl = '';
  bool _isLoadingProfile = true;
  bool _isUploadingAvatar = false;
  bool _isSavingProfile = false;

  // Per-prayer settings
  static const _prayerKeys = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];
  static const _prayerEmojis = ['🌅', '☀️', '🌤️', '🌇', '🌙'];
  static const _prayerNames = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
  Map<String, bool> _prayerEnabled = {};
  Map<String, int> _prayerOffset = {};

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

    // Load per-prayer settings
    _prayerEnabled = {
      for (final k in _prayerKeys)
        k: sharedPrefs.getBool('prayerEnabled_$k') ?? true,
    };
    _prayerOffset = {
      for (final k in _prayerKeys)
        k: sharedPrefs.getInt('prayerOffset_$k') ?? 10,
    };

    _manualTimes = {
      'fajr': sharedPrefs.getString('manual_fajr') ?? '05:00',
      'dhuhr': sharedPrefs.getString('manual_dhuhr') ?? '12:30',
      'asr': sharedPrefs.getString('manual_asr') ?? '15:45',
      'maghrib': sharedPrefs.getString('manual_maghrib') ?? '18:15',
      'isha': sharedPrefs.getString('manual_isha') ?? '19:30',
    };
    _loadProfile();
  }

  @override
  void dispose() {
    _resetController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = supabaseClient.auth.currentUser;
    if (user == null) return;

    setState(() {
      _profileEmail = user.email ?? '';
      _isLoadingProfile = true;
    });

    final data = await supabaseService.fetchProfile(user.id);
    if (mounted) {
      setState(() {
        _profileName = data?['full_name']?.toString() ?? '';
        _profileAvatarUrl = data?['avatar_url']?.toString() ?? '';
        _isLoadingProfile = false;
      });
    }
  }

  Future<void> _updateProfileName(String newName) async {
    final user = supabaseClient.auth.currentUser;
    if (user == null) return;

    setState(() => _isSavingProfile = true);
    try {
      await supabaseService.updateProfile(user.id, newName, null);
      if (mounted) {
        setState(() {
          _profileName = newName;
          _isSavingProfile = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Name updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSavingProfile = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating name: $e')),
        );
      }
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final user = supabaseClient.auth.currentUser;
    if (user == null) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Change Profile Photo',
                style: AppTypography.body(
                  size: 16,
                  weight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Take Photo'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );

    if (file == null) return;

    setState(() => _isUploadingAvatar = true);
    try {
      final bytes = await file.readAsBytes();
      final ext = file.path.split('.').last.toLowerCase();
      String mimeType = 'image/jpeg';
      if (ext == 'png') {
        mimeType = 'image/png';
      } else if (ext == 'webp') {
        mimeType = 'image/webp';
      }

      final publicUrl = await supabaseService.uploadAvatar(
        user.id,
        bytes,
        ext,
        mimeType,
      );

      await supabaseService.updateProfile(user.id, _profileName, publicUrl);

      if (mounted) {
        setState(() {
          _profileAvatarUrl = publicUrl;
          _isUploadingAvatar = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Avatar uploaded successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading image: $e')),
        );
      }
    }
  }

  String _getInitials(String name) {
    if (name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      if (parts[0].length >= 2) {
        return parts[0].substring(0, 2).toUpperCase();
      }
      return parts[0].substring(0, 1).toUpperCase();
    }
    final first = parts[0].isNotEmpty ? parts[0].substring(0, 1) : '';
    final second = parts[1].isNotEmpty ? parts[1].substring(0, 1) : '';
    return (first + second).toUpperCase();
  }

  Future<void> _showEditNameDialog() async {
    final controller = TextEditingController(text: _profileName);
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Edit Name',
          style: AppTypography.body(
            size: 16,
            weight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            style: AppTypography.body(color: AppColors.textPrimary),
            decoration: InputDecoration(
              labelText: 'Full Name',
              labelStyle: TextStyle(color: AppColors.textSecondary),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.primary),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Name cannot be empty';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: AppTypography.body(size: 13, color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                final newName = controller.text.trim();
                Navigator.pop(ctx);
                await _updateProfileName(newName);
              }
            },
            child: Text(
              'Save',
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
  }

  Future<void> _toggleSessionReminders(bool value) async {
    setState(() => _sessionReminders = value);
    await sharedPrefs.setBool('sessionReminders', value);
    await _rescheduleNotifications();
  }

  Future<void> _togglePrayerAlerts(bool value) async {
    setState(() => _prayerAlerts = value);
    await sharedPrefs.setBool('prayerAlerts', value);
    await _rescheduleNotifications();
  }

  Future<void> _togglePrayerEnabled(String key, bool value) async {
    setState(() => _prayerEnabled[key] = value);
    await sharedPrefs.setBool('prayerEnabled_$key', value);
    await _rescheduleNotifications();
  }

  Future<void> _pickPrayerOffset(String key) async {
    final current = _prayerOffset[key] ?? 10;
    int tempOffset = current;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          height: 280,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Alert offset — ${_prayerNames[_prayerKeys.indexOf(key)]}',
                style: AppTypography.body(size: 16, weight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'Minutes after the adhan to send the alert',
                style: AppTypography.body(size: 13, color: AppColors.textMuted),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final mins in [0, 5, 10, 15, 20, 30, 45, 60])
                    GestureDetector(
                      onTap: () => setSheet(() => tempOffset = mins),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: tempOffset == mins ? AppColors.primary : AppColors.surfaceRaised,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            '$mins',
                            style: AppTypography.mono(
                              size: 13,
                              weight: FontWeight.w700,
                              color: tempOffset == mins ? Colors.white : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    setState(() => _prayerOffset[key] = tempOffset);
                    await sharedPrefs.setInt('prayerOffset_$key', tempOffset);
                    await _rescheduleNotifications();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Save — $tempOffset min after adhan',
                    style: AppTypography.body(size: 14, weight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _rescheduleNotifications() async {
    await notificationService.scheduleSessionNotifications(
      sessionRemindersEnabled: _sessionReminders,
      prayerAlertsEnabled: _prayerAlerts,
      prayerEnabled: _prayerEnabled,
      prayerOffset: _prayerOffset,
    );
  }

  Future<void> _changeLocation() async {
    setState(() => _isLocating = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isLocating = false);
        final bool openSettings = await _showConfirm(
          title: 'Location Disabled',
          message:
              'Location services are disabled. Would you like to enable them in settings?',
        );
        if (openSettings) {
          await Geolocator.openLocationSettings();
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _isLocating = false);
        final bool openSettings = await _showConfirm(
          title: 'Permission Denied',
          message:
              'Location permissions are permanently denied. Please enable them in app settings.',
        );
        if (openSettings) {
          await Geolocator.openAppSettings();
        }
        return;
      }

      Position position = await Geolocator.getCurrentPosition();

      await sharedPrefs.setDouble('prayer_lat', position.latitude);
      await sharedPrefs.setDouble('prayer_lng', position.longitude);

      List<Placemark> placemarks = [];
      try {
        placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
      } catch (e) {
        // Geocoding may not be supported on this platform (e.g., Web)
      }

      String newLocation = 'Unknown Location';
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final city =
            place.locality ??
            place.subAdministrativeArea ??
            place.administrativeArea ??
            '';
        final country = place.country ?? '';
        newLocation = city.isNotEmpty && country.isNotEmpty
            ? '$city, $country'
            : city.isNotEmpty
            ? city
            : country;
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
          SnackBar(
            content: Text(
              'Error: ${e.toString().replaceAll('Exception: ', '')}',
            ),
          ),
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
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
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

  Future<void> _resetStreak() async {
    final confirm = await _showConfirm(
      title: 'Reset Streak',
      message: 'This will reset your streak to 0. Continue?',
    );
    if (!confirm) return;

    await streakService.resetStreak();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Streak reset.')));
    }
  }

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

    await hiveService.clearAll();
    await supabaseService.resetAllData(deviceId);

    // Also restart empty states for today locally
    final today = dateService.todayKey();
    await hiveService.writeDailyState(DailyState.empty(today));

    // Invalidate providers so UI reloads from empty state
    ref.invalidate(sessionsProvider);
    ref.invalidate(completionPctProvider);

    setState(() => _isResetting = false);

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('All data reset. Starting fresh.')));
      
      context.go('/home');
    }
  }

  Future<void> _signOut() async {
    final confirm = await _showConfirm(
      title: 'Sign Out',
      message: 'Are you sure you want to sign out?',
    );
    if (!confirm) return;

    await Supabase.instance.client.auth.signOut();
    final newId = const Uuid().v4();
    await sharedPrefs.setString('deviceId', newId);
    deviceId = newId;

    // Reset local cache to empty state
    await hiveService.clearAll();
    await hiveService.writeCustomTasks([]);

    // Invalidate providers
    ref.invalidate(sessionsProvider);
    ref.invalidate(completionPctProvider);

    if (mounted) {
      context.go('/auth');
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
                const _SectionHeader(title: 'Account & Profile'),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: AppColors.cardDecoration(),
                  child: _isLoadingProfile
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          ),
                        )
                      : Row(
                          children: [
                            GestureDetector(
                              onTap: _isUploadingAvatar ? null : _pickAndUploadAvatar,
                              child: Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 36,
                                    backgroundColor: AppColors.primary,
                                    backgroundImage: _profileAvatarUrl.isNotEmpty
                                        ? NetworkImage(_profileAvatarUrl)
                                        : null,
                                    child: _profileAvatarUrl.isEmpty
                                        ? Text(
                                            _getInitials(_profileName),
                                            style: AppTypography.body(
                                              size: 20,
                                              weight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          )
                                        : null,
                                  ),
                                  if (_isUploadingAvatar)
                                    Positioned.fill(
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          color: Colors.black45,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Center(
                                          child: SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                  else
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 1.5),
                                        ),
                                        child: const Icon(
                                          Icons.camera_alt,
                                          size: 12,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  GestureDetector(
                                    onTap: _isSavingProfile ? null : _showEditNameDialog,
                                    behavior: HitTestBehavior.opaque,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            _profileName.isNotEmpty ? _profileName : 'Add Name',
                                            style: AppTypography.body(
                                              size: 16,
                                              weight: FontWeight.w600,
                                              color: _profileName.isNotEmpty
                                                  ? AppColors.textPrimary
                                                  : AppColors.textMuted,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        if (_isSavingProfile)
                                          const SizedBox(
                                            width: 12,
                                            height: 12,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 1.5,
                                            ),
                                          )
                                        else
                                          Icon(
                                            Icons.edit_outlined,
                                            size: 14,
                                            color: AppColors.textMuted,
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _profileEmail,
                                    style: AppTypography.body(
                                      size: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: AppColors.complete,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Cloud sync active',
                                        style: AppTypography.label(
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 24),
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
                  subtitle: _prayerAlerts
                      ? '${_prayerEnabled.values.where((v) => v).length} of ${_prayerKeys.length} prayers active'
                      : 'All prayer alerts off',
                  trailing: CupertinoSwitch(
                    value: _prayerAlerts,
                    activeTrackColor: AppColors.complete,
                    onChanged: _togglePrayerAlerts,
                  ),
                ),
                // Per-prayer settings (visible only when global toggle is ON)
                if (_prayerAlerts)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: AppColors.cardSurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: List.generate(_prayerKeys.length, (i) {
                        final key = _prayerKeys[i];
                        final enabled = _prayerEnabled[key] ?? true;
                        final offset = _prayerOffset[key] ?? 10;
                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              child: Row(
                                children: [
                                  Text(
                                    _prayerEmojis[i],
                                    style: const TextStyle(fontSize: 18),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _prayerNames[i],
                                          style: AppTypography.body(
                                            size: 14,
                                            weight: FontWeight.w500,
                                            color: enabled ? AppColors.textPrimary : AppColors.textMuted,
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: enabled ? () => _pickPrayerOffset(key) : null,
                                          child: Text(
                                            enabled ? '$offset min after adhan ›' : 'Disabled',
                                            style: AppTypography.label(
                                              color: enabled ? AppColors.primary : AppColors.textMuted,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  CupertinoSwitch(
                                    value: enabled,
                                    activeTrackColor: AppColors.complete,
                                    onChanged: (val) => _togglePrayerEnabled(key, val),
                                  ),
                                ],
                              ),
                            ),
                            if (i < _prayerKeys.length - 1)
                              Divider(
                                height: 1,
                                indent: 14,
                                endIndent: 14,
                                color: AppColors.border,
                              ),
                          ],
                        );
                      }),
                    ),
                  ),

                SizedBox(height: 24),

                const _SectionHeader(title: 'Location Settings'),
                _SettingsTile(
                  icon: Icons.my_location_outlined,
                  title: 'Location',
                  subtitle: _prayerLocation,
                  onTap: _isLocating ? null : _changeLocation,
                  trailing: _isLocating
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        )
                      : Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: AppColors.textMuted,
                        ),
                ),

                SizedBox(height: 24),

                const _SectionHeader(title: 'Prayer Times'),
                Row(
                  children: [
                    Expanded(
                      child: CupertinoSegmentedControl<String>(
                        groupValue: _prayerMode,
                        children: {
                          'auto': Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'Automatic',
                              style: AppTypography.body(
                                size: 13,
                                color: _prayerMode == 'auto'
                                    ? Colors.white
                                    : AppColors.primary,
                              ),
                            ),
                          ),
                          'manual': Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'Manual',
                              style: AppTypography.body(
                                size: 13,
                                color: _prayerMode == 'manual'
                                    ? Colors.white
                                    : AppColors.primary,
                              ),
                            ),
                          ),
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
                  _SettingsTile(
                    icon: Icons.wb_twilight,
                    title: 'Fajr',
                    trailing: Text(
                      _manualTimes['fajr']!,
                      style: AppTypography.mono(color: AppColors.primary),
                    ),
                    onTap: () => _pickManualTime('fajr'),
                  ),
                  _SettingsTile(
                    icon: Icons.wb_sunny_rounded,
                    title: 'Dhuhr',
                    trailing: Text(
                      _manualTimes['dhuhr']!,
                      style: AppTypography.mono(color: AppColors.primary),
                    ),
                    onTap: () => _pickManualTime('dhuhr'),
                  ),
                  _SettingsTile(
                    icon: Icons.wb_sunny_outlined,
                    title: 'Asr',
                    trailing: Text(
                      _manualTimes['asr']!,
                      style: AppTypography.mono(color: AppColors.primary),
                    ),
                    onTap: () => _pickManualTime('asr'),
                  ),
                  _SettingsTile(
                    icon: Icons.cloud_outlined,
                    title: 'Maghrib',
                    trailing: Text(
                      _manualTimes['maghrib']!,
                      style: AppTypography.mono(color: AppColors.primary),
                    ),
                    onTap: () => _pickManualTime('maghrib'),
                  ),
                  _SettingsTile(
                    icon: Icons.nights_stay_outlined,
                    title: 'Isha',
                    trailing: Text(
                      _manualTimes['isha']!,
                      style: AppTypography.mono(color: AppColors.primary),
                    ),
                    onTap: () => _pickManualTime('isha'),
                  ),
                ],

                SizedBox(height: 24),

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
                _SettingsTile(
                  icon: Icons.logout_rounded,
                  title: 'Sign out',
                  onTap: _signOut,
                ),

                SizedBox(height: 52),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'FocusFlow',
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
                        final uri = Uri.parse(
                          'https://javithnaseem.netlify.app',
                        );
                        try {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        } catch (_) {
                          try {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.platformDefault,
                            );
                          } catch (_) {}
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
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

// Section Header

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

// Settings Tile

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
              Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
