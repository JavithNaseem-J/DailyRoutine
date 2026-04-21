import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'core/services/hive_service.dart';
import 'core/services/lifecycle_service.dart';
import 'core/services/notification_service.dart';
import 'app.dart';

// ─── Supabase credentials ────────────────────────────────────────────────────
const _supabaseUrl = 'https://rbfzonbeqytzkdomcfev.supabase.co';
const _supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
    '.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJiZnpvbmJlcXl0emtkb21jZmV2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU5MjkzMDcsImV4cCI6MjA5MTUwNTMwN30'
    '.YmQIN686N7fj56Q6tk0CO9jd1kAfJ7wlVon6iLV22FA';

/// Global shared preferences + deviceId — accessed throughout the app.
late SharedPreferences sharedPrefs;
late String deviceId;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Lock to portrait ───────────────────────────────────────────────
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ── Status bar styling ─────────────────────────────────────────────
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // ── Supabase ───────────────────────────────────────────────────────
  await Supabase.initialize(url: _supabaseUrl, anonKey: _supabaseAnonKey);

  sharedPrefs = await SharedPreferences.getInstance();
  
  final session = Supabase.instance.client.auth.currentSession;
  if (session != null) {
    sharedPrefs.setString('deviceId', session.user.id);
  } else if (!sharedPrefs.containsKey('deviceId')) {
    sharedPrefs.setString('deviceId', const Uuid().v4());
  }
  deviceId = sharedPrefs.getString('deviceId')!;

  // ── Hive local cache (mobile/desktop only) ────────────────────────────
  if (!kIsWeb) {
    await hiveService.init();
  }

  // ── Midnight reset + Notifications (mobile only) ─────────────────────
  if (!kIsWeb) {
    lifecycleService.init();
    await notificationService.init();
    final sessionReminders = sharedPrefs.getBool('sessionReminders') ?? true;
    final prayerAlerts = sharedPrefs.getBool('prayerAlerts') ?? true;
    
    notificationService
        .scheduleSessionNotifications(
          sessionRemindersEnabled: sessionReminders,
          prayerAlertsEnabled: prayerAlerts,
        )
        .catchError((_) {});
  }

  runApp(
    // Riverpod scope wraps the whole app
    const ProviderScope(child: DailyRoutineApp()),
  );
}
