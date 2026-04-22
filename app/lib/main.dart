import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
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

/// Global shared preferences + deviceId — accessed throughout the app.
late SharedPreferences sharedPrefs;
late String deviceId;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables based on Build configuration
  const envFile = String.fromEnvironment('ENV', defaultValue: '.env.dev');
  await dotenv.load(fileName: envFile);

  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  final supabaseKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

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
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);

  sharedPrefs = await SharedPreferences.getInstance();
  
  final session = Supabase.instance.client.auth.currentSession;
  if (session != null) {
    sharedPrefs.setString('deviceId', session.user.id);
  } else if (!sharedPrefs.containsKey('deviceId')) {
    sharedPrefs.setString('deviceId', const Uuid().v4());
  }
  deviceId = sharedPrefs.getString('deviceId')!;

  // ── Hive local cache (mobile only) ────────────────────────────
  await hiveService.init();

  // ── Midnight reset + Notifications (mobile only) ─────────────────────
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

  await SentryFlutter.init(
    (options) {
      options.dsn = dotenv.env['SENTRY_DSN'] ?? '';
      options.tracesSampleRate = 1.0;
    },
    appRunner: () => runApp(
      // Riverpod scope wraps the whole app
      const ProviderScope(child: DailyRoutineApp()),
    ),
  );
}
