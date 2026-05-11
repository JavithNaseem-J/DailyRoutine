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

// NEW-BUG-007 fix: fail fast with a clear message if secrets are not injected.
// Build with: flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=... --dart-define=SENTRY_DSN=...
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseKey = String.fromEnvironment('SUPABASE_ANON_KEY');
const _sentryDsn = String.fromEnvironment('SENTRY_DSN');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // NEW-BUG-007: gracefully handle missing secrets instead of a blank white screen
  if (_supabaseUrl.isEmpty || _supabaseKey.isEmpty) {
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'Missing Supabase Configuration.\n\n'
                'You must inject secrets at build time using:\n\n'
                'flutter run --dart-define=SUPABASE_URL=<url> --dart-define=SUPABASE_ANON_KEY=<key>',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return;
  }

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  await SentryFlutter.init(
    (options) {
      options.dsn = _sentryDsn;
      options.tracesSampleRate = 0.1; // 10% sampling — avoids quota burn in production
    },
    appRunner: () async {
      try {
        await Supabase.initialize(url: _supabaseUrl, anonKey: _supabaseKey);
        
        sharedPrefs = await SharedPreferences.getInstance();
        
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          await sharedPrefs.setString('deviceId', session.user.id);
        } else {
          try {
            final res = await Supabase.instance.client.auth.signInAnonymously();
            if (res.session != null) {
              await sharedPrefs.setString('deviceId', res.session!.user.id);
            }
          } catch (_) {}
        }
        
        if (!sharedPrefs.containsKey('deviceId')) {
          await sharedPrefs.setString('deviceId', const Uuid().v4());
        }
        deviceId = sharedPrefs.getString('deviceId')!;

        await hiveService.init();

        lifecycleService.init();
        await notificationService.init();
        final sessionReminders = sharedPrefs.getBool('sessionReminders') ?? true;
        final prayerAlerts = sharedPrefs.getBool('prayerAlerts') ?? true;
        final disabledSessions = sharedPrefs.getStringList('disabledSessions') ?? [];
        
        notificationService
            .scheduleSessionNotifications(
              sessionRemindersEnabled: sessionReminders,
              prayerAlertsEnabled: prayerAlerts,
              disabledSessionIds: disabledSessions.toSet(),
            )
            .catchError((e, st) {
              Sentry.captureException(e, stackTrace: st);
            });
            
        runApp(const ProviderScope(child: DailyRoutineApp()));
      } catch (e, st) {
        Sentry.captureException(e, stackTrace: st);
        runApp(const MaterialApp(home: Scaffold(body: Center(child: Text('App Initialization Failed')))));
      }
    },
  );
}
