import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/session_data.dart';
import '../../core/models/session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/day_checker.dart';
import '../../core/utils/duration_formatter.dart';
import 'providers/sessions_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Sessions Screen — wired to sessionsProvider (Phase 3B)
// ─────────────────────────────────────────────────────────────────────────────

class SessionsScreen extends ConsumerStatefulWidget {
  const SessionsScreen({super.key});

  @override
  ConsumerState<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends ConsumerState<SessionsScreen> {
  late final PageController _pageController;
  late final ScrollController _pillScrollController;
  int _currentIndex = 0;

  List<Session> get _sessions =>
      ref.read(sessionsProvider).value?.sessions ??
      SessionData.sessionsForToday(
        isFriday: DayChecker.isFriday(),
        isSunday: DayChecker.isSunday(),
      );

  @override
  void initState() {
    super.initState();
    final sessions = SessionData.sessionsForToday(
      isFriday: DayChecker.isFriday(),
      isSunday: DayChecker.isSunday(),
    );
    _currentIndex = _findActiveSessionIndex(sessions);
    _pageController = PageController(initialPage: _currentIndex);
    _pillScrollController = ScrollController();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _scrollPillToIndex(_currentIndex));
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pillScrollController.dispose();
    super.dispose();
  }

  // ── Active session from current time ───────────────────────────────
  int _findActiveSessionIndex(List<Session> sessions) {
    final now = TimeOfDay.now();
    final nowMin = now.hour * 60 + now.minute;
    for (int i = 0; i < sessions.length; i++) {
      final range = sessions[i].timeRange.split('–').map((p) => p.trim()).toList();
      if (range.length != 2) continue;
      if (nowMin >= _parseTime(range[0]) && nowMin < _parseTime(range[1])) {
        return i;
      }
    }
    return 0;
  }

  int _parseTime(String t) {
    t = t.toLowerCase().replaceAll(' ', '');
    final isPm = t.contains('pm');
    t = t.replaceAll('pm', '').replaceAll('am', '');
    final p = t.split(':');
    int h = int.parse(p[0]);
    final m = p.length > 1 ? int.parse(p[1]) : 0;
    if (isPm && h != 12) h += 12;
    return h * 60 + m;
  }

  // ── Navigation ─────────────────────────────────────────────────────
  void _onPillTap(int index) {
    setState(() => _currentIndex = index);
    _pageController.animateToPage(index,
        duration: const Duration(milliseconds: 320), curve: Curves.easeInOut);
    _scrollPillToIndex(index);
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    _scrollPillToIndex(index);
  }

  void _scrollPillToIndex(int index) {
    final offset = (index * 104.0) - 40;
    if (_pillScrollController.hasClients) {
      _pillScrollController.animateTo(
        offset.clamp(0.0, _pillScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // ── Delegate toggles to provider ───────────────────────────────────
  void _toggleTask(String taskId) =>
      ref.read(sessionsProvider.notifier).toggleTask(taskId);

  void _toggleBonus(String taskId) =>
      ref.read(sessionsProvider.notifier).toggleBonus(taskId);

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(sessionsProvider);
    final sessions = sessionsAsync.value?.sessions ?? _sessions;
    final safeIndex = _currentIndex.clamp(0, sessions.length - 1);
    final session = sessions[safeIndex];
    final taskStates = sessionsAsync.value?.taskStates ?? {};
    final bonusStates = sessionsAsync.value?.bonusStates ?? {};

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Task',
                          style: AppTypography.screenTitle(
                              color: AppColors.textPrimary)),
                    ],
                  ),
                  const Icon(Icons.more_horiz, color: AppColors.textSecondary),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Pill row ─────────────────────────────────────────────
            SizedBox(
              height: 38,
              child: ListView.separated(
                controller: _pillScrollController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: sessions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final s = sessions[i];
                  final doneCount = s.tasks.where((t) => taskStates[t.id] == true).length;
                  final total = s.tasks.length;
                  final percent = total == 0 ? 0.0 : doneCount / total;
                  
                  final now = TimeOfDay.now();
                  final nowMin = now.hour * 60 + now.minute;
                  bool isFuture = false;
                  final range = s.timeRange.split('–').map((p) => p.trim()).toList();
                  if (range.isNotEmpty) {
                    final startMin = _parseTime(range[0]);
                    isFuture = nowMin < startMin;
                  }

                  return _SessionPill(
                    session: s,
                    isSelected: i == safeIndex,
                    percent: percent,
                    isFuture: isFuture,
                    onTap: () => _onPillTap(i),
                  );
                },
              ),
            ),

            const SizedBox(height: 4),
            const Divider(height: 1, color: AppColors.border),

            // ── Session pages ────────────────────────────────────────
            Expanded(
              child: sessionsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
                error: (e, _) => Center(
                  child: Text('Error loading sessions',
                      style: AppTypography.body(color: AppColors.textMuted)),
                ),
                data: (_) => PageView.builder(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  itemCount: sessions.length,
                  itemBuilder: (context, i) => _SessionPage(
                    session: sessions[i],
                    taskStates: taskStates,
                    bonusStates: bonusStates,
                    onToggleTask: _toggleTask,
                    onToggleBonus: _toggleBonus,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Session Pill
// ─────────────────────────────────────────────────────────────────────────────

class _SessionPill extends StatelessWidget {
  const _SessionPill({
    required this.session,
    required this.isSelected,
    required this.percent,
    required this.isFuture,
    required this.onTap,
  });

  final Session session;
  final bool isSelected;
  final double percent;
  final bool isFuture;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    Color borderColor;

    if (isSelected) {
      bgColor = AppColors.primary;
      textColor = Colors.white;
      borderColor = AppColors.primary;
    } else if (isFuture) {
      bgColor = Colors.white;
      textColor = AppColors.textSecondary;
      borderColor = AppColors.border;
    } else {
      if (percent == 0.0) {
        bgColor = const Color(0xFFF3F4F6); // Stage 1 (0%)
        textColor = AppColors.textPrimary;
        borderColor = const Color(0xFFE5E7EB);
      } else if (percent <= 0.33) {
        bgColor = const Color(0xFFFEF9C3); // Stage 2
        textColor = const Color(0xFF854D0E);
        borderColor = const Color(0xFFFEF08A);
      } else if (percent <= 0.66) {
        bgColor = const Color(0xFFFEF08A); // Stage 3
        textColor = const Color(0xFF854D0E);
        borderColor = const Color(0xFFFDE047);
      } else if (percent < 1.0) {
        bgColor = const Color(0xFFDCFCE7); // Stage 4
        textColor = const Color(0xFF166534);
        borderColor = const Color(0xFF86EFAC);
      } else {
        bgColor = AppColors.complete;      // Stage 5 (100%)
        textColor = Colors.white;
        borderColor = AppColors.complete;
      }
    }

    final is100 = percent == 1.0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (is100 && !isSelected)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Icons.check, size: 12, color: Colors.white),
                ),
              Text(
                session.name,
                style: AppTypography.body(
                  size: 12,
                  weight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Session Page  (one per session in PageView)
// ─────────────────────────────────────────────────────────────────────────────

class _SessionPage extends StatelessWidget {
  const _SessionPage({
    required this.session,
    required this.taskStates,
    required this.bonusStates,
    required this.onToggleTask,
    required this.onToggleBonus,
  });

  final Session session;
  final Map<String, bool> taskStates;
  final Map<String, bool> bonusStates;
  final ValueChanged<String> onToggleTask;
  final ValueChanged<String> onToggleBonus;

  @override
  Widget build(BuildContext context) {
    final doneCount =
        session.tasks.where((t) => taskStates[t.id] == true).length;
    final isAllDone = doneCount == session.tasks.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: [
        if (isAllDone) ...[
          _SessionCompleteBanner(sessionName: session.name),
          const SizedBox(height: 24),
        ],
        ...session.tasks.asMap().entries.map((entry) {
          final index = entry.key;
          final task = entry.value;
          return _TaskCard(
            task: task,
            isDone: taskStates[task.id] ?? false,
            isLast: index == session.tasks.length - 1,
            onToggle: () => onToggleTask(task.id),
          );
        }),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Timeline Painter
// ─────────────────────────────────────────────────────────────────────────────

class _TimelinePainter extends CustomPainter {
  final bool isLast;
  
  _TimelinePainter({this.isLast = false});

  @override
  void paint(Canvas canvas, Size size) {
    if (isLast) return;
    
    final paint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
      
    final double dashWidth = 4, dashSpace = 4;
    double startY = 32; // Start line slightly below the circle
    while (startY < size.height) {
      canvas.drawLine(
        Offset(size.width / 2, startY),
        Offset(size.width / 2, (startY + dashWidth).clamp(0.0, size.height)),
        paint,
      );
      startY += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter oldDelegate) => 
      oldDelegate.isLast != isLast;
}

// ─────────────────────────────────────────────────────────────────────────────
// Task Card (Timeline Style)
// ─────────────────────────────────────────────────────────────────────────────

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.isDone,
    required this.isLast,
    required this.onToggle,
  });

  final Task task;
  final bool isDone;
  final bool isLast;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline Graphics Column
          SizedBox(
            width: 32,
            child: CustomPaint(
              painter: _TimelinePainter(isLast: isLast),
              child: Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: GestureDetector(
                    onTap: onToggle,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDone ? const Color(0xFF4ade80) : Colors.white,
                        border: isDone 
                            ? null 
                            : Border.all(color: const Color(0xFFD1D5DB), width: 1.5),
                      ),
                      child: isDone
                          ? const Icon(Icons.check, size: 12, color: Colors.white)
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Content Column
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 28),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: AppTypography.body(
                            size: 15,
                            weight: FontWeight.w600,
                            color: isDone ? const Color(0xFF9CA3AF) : AppColors.textPrimary,
                          ).copyWith(
                            decoration: isDone ? TextDecoration.lineThrough : TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        task.time,
                        style: AppTypography.mono(
                          size: 12, 
                          color: const Color(0xFF9CA3AF),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${task.durationMinutes} min',
                        style: AppTypography.body(
                          size: 11, 
                          weight: FontWeight.w600,
                          color: const Color(0xFFD1D5DB),
                        ),
                      ),
                    ],
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
// ─────────────────────────────────────────────────────────────────────────────
// Session Complete Banner
// ─────────────────────────────────────────────────────────────────────────────

class _SessionCompleteBanner extends StatelessWidget {
  const _SessionCompleteBanner({required this.sessionName});
  final String sessionName;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.9, end: 1.0),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.completeFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: AppColors.complete.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: AppColors.complete, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$sessionName complete!',
                      style: AppTypography.body(
                          size: 14,
                          weight: FontWeight.w600,
                          color: const Color(0xFF166634))),
                  Text('بارك الله فيك',
                      style: AppTypography.body(
                          size: 12, color: const Color(0xFF166634))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
