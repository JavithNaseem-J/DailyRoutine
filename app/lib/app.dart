import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';

import 'features/home/home_screen.dart';
import 'features/sessions/sessions_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/stats/stats_screen.dart';
import 'features/quran/quran_screen.dart';
import 'features/focus/focus_screen.dart';
import 'features/auth/auth_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DailyRoutineApp extends StatefulWidget {
  const DailyRoutineApp({super.key});

  @override
  State<DailyRoutineApp> createState() => _DailyRoutineAppState();
}

// NEW-BUG-004 fix: listen for session expiry and redirect to /auth
class _DailyRoutineAppState extends State<DailyRoutineApp> {
  @override
  void initState() {
    super.initState();
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.signedOut ||
          (event == AuthChangeEvent.tokenRefreshed && data.session == null)) {
        if (mounted) _router.go('/auth');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Yawmi',
      theme: AppTheme.theme(),
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GoRouter — ShellRoute with 3-tab bottom nav
// ─────────────────────────────────────────────────────────────────────────────

final _router = GoRouter(
  initialLocation: '/home',
  // NEW-BUG-003 fix: handle unknown routes with a friendly fallback screen
  errorBuilder: (context, state) => Scaffold(
    backgroundColor: AppColors.background,
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.explore_off_outlined,
              size: 64, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          Text('Page not found',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => context.go('/home'),
            child: const Text('Go Home'),
          ),
        ],
      ),
    ),
  ),
  redirect: (context, state) {
    final session = Supabase.instance.client.auth.currentSession;
    final isAuthRoute = state.matchedLocation == '/auth';

    if (session == null && !isAuthRoute) return '/auth';
    if (session != null && isAuthRoute) return '/home';
    return null;
  },
  routes: [
    GoRoute(
      path: '/auth',
      builder: (context, state) => const AuthScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) => _AppShell(child: child),
      routes: [
        GoRoute(
          path: '/home',
          pageBuilder: (context, state) => CustomTransitionPage(
            child: const HomeScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        ),
        GoRoute(
          path: '/sessions',
          pageBuilder: (context, state) => CustomTransitionPage(
            child: const SessionsScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        ),
        GoRoute(
          path: '/stats',
          pageBuilder: (context, state) => CustomTransitionPage(
            child: const StatsScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        ),
      ],
    ),
    // Settings — full-screen, no bottom nav
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    // Quran Reader — full-screen, no bottom nav
    GoRoute(
      path: '/quran/reader',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final page = extra?['page'] as int? ?? 1;
        return QuranScreen(initialPage: page);
      },
    ),
    // Focus Mode — full-screen, no bottom nav
    GoRoute(
      path: '/focus',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return FocusScreen(
          taskTitle: extra?['taskTitle'] as String? ?? 'Focus Session',
          durationMinutes: extra?['durationMinutes'] as int? ?? 25,
        );
      },
    ),
  ],
);

// ─────────────────────────────────────────────────────────────────────────────
// App Shell — wraps each tab with the shared bottom navigation bar
// ─────────────────────────────────────────────────────────────────────────────

class _AppShell extends StatelessWidget {
  const _AppShell({required this.child});

  final Widget child;

  int _tabIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/sessions')) return 1;
    if (location.startsWith('/stats')) return 2;
    return 0;
  }

  void _onTabTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/sessions');
        break;
      case 2:
        context.go('/stats');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final index = _tabIndex(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      body: Stack(
        children: [
          child,
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                decoration: BoxDecoration(
                  color: AppColors.navBackground,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildNavItem(
                        0,
                        Icons.home_outlined,
                        Icons.home,
                        index,
                        context,
                      ),
                      _buildNavItem(
                        1,
                        Icons.access_time_outlined,
                        Icons.access_time_filled,
                        index,
                        context,
                      ),
                      _buildNavItem(
                        2,
                        Icons.bar_chart_outlined,
                        Icons.bar_chart,
                        index,
                        context,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    int i,
    IconData out,
    IconData fill,
    int currentIndex,
    BuildContext context,
  ) {
    final active = currentIndex == i;
    return GestureDetector(
      onTap: () => _onTabTap(context, i),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? Colors.white.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          active ? fill : out,
          color: active ? Colors.white : AppColors.navInactive,
          size: 26,
        ),
      ),
    );
  }
}
