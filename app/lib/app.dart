import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';
import 'features/home/home_screen.dart';
import 'features/sessions/sessions_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/stats/stats_screen.dart';

class DailyRoutineApp extends StatelessWidget {
  const DailyRoutineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Daily Routine',
      theme: AppTheme.light,
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
  routes: [
    ShellRoute(
      builder: (context, state, child) => _AppShell(child: child),
      routes: [
        GoRoute(
          path: '/home',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: HomeScreen(),
          ),
        ),
        GoRoute(
          path: '/sessions',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: SessionsScreen(),
          ),
        ),
        GoRoute(
          path: '/stats',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: StatsScreen(),
          ),
        ),
      ],
    ),
    // Settings — full-screen, no bottom nav
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
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
      case 0: context.go('/home'); break;
      case 1: context.go('/sessions'); break;
      case 2: context.go('/stats'); break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final index = _tabIndex(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: SafeArea(
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
              )
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.home_outlined, Icons.home, index, context),
                _buildNavItem(1, Icons.access_time_outlined, Icons.access_time_filled, index, context),
                _buildNavItem(2, Icons.bar_chart_outlined, Icons.bar_chart, index, context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int i, IconData out, IconData fill, int currentIndex, BuildContext context) {
    final active = currentIndex == i;
    return GestureDetector(
      onTap: () => _onTabTap(context, i),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: active ? Colors.white.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(active ? fill : out, color: active ? Colors.white : AppColors.navInactive, size: 26),
      ),
    );
  }
}
