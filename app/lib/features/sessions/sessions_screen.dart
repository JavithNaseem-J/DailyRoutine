import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:confetti/confetti.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/session_data.dart';
import '../../core/models/session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import 'add_task_sheet.dart';
import 'providers/sessions_provider.dart';
import '../focus/providers/focus_timer_provider.dart';
import '../../core/services/date_service.dart';

class SessionsScreen extends ConsumerStatefulWidget {
  const SessionsScreen({super.key});

  @override
  ConsumerState<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends ConsumerState<SessionsScreen> {
  late final PageController _pageController;
  late final ScrollController _pillScrollController;
  late final ConfettiController _confettiController;
  int _currentIndex = 0;
  List<Session> get _sessions =>
      ref.read(sessionsProvider).value?.sessions ??
      SessionData.sessionsForToday;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );
    final sessions = SessionData.sessionsForToday;
    _currentIndex = _findActiveSessionIndex(sessions);
    _pageController = PageController(initialPage: _currentIndex);
    _pillScrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollPillToIndex(_currentIndex),
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _pageController.dispose();
    _pillScrollController.dispose();
    ref.read(sessionsProvider.notifier).changeDate(dateService.todayKey());
    super.dispose();
  }

  int _findActiveSessionIndex(List<Session> sessions) {
    final now = TimeOfDay.now();
    final nowMin = now.hour * 60 + now.minute;
    for (int i = 0; i < sessions.length; i++) {
      if (sessions[i].id == 'key_tasks') continue;
      final range = sessions[i].timeRange
          .split(RegExp(r'\s*[-–—]\s*'))
          .map((p) => p.trim())
          .toList();
      if (range.length != 2) continue;
      if (nowMin >= _parseTime(range[0]) && nowMin < _parseTime(range[1])) {
        return i;
      }
    }
    return 0;
  }

  int _parseTime(String t) {
    t = t.toLowerCase().replaceAll(' ', '');
    if (t == 'allday' || t.isEmpty) return 0;
    final isPm = t.contains('pm');
    final isAm = t.contains('am');
    t = t.replaceAll('pm', '').replaceAll('am', '');
    final p = t.split(':');
    int h = int.tryParse(p[0]) ?? 0;
    final m = p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0;
    if (isPm && h != 12) h += 12;
    if (isAm && h == 12) h = 0;
    return h * 60 + m;
  }

  void _onPillTap(int index) {
    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
    );
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

  void _setTaskStatus(Task task, String status) {
    HapticFeedback.lightImpact();

    final selectedDateStr = ref.read(sessionsProvider).value?.selectedDate ?? dateService.todayKey();
    if (selectedDateStr != dateService.todayKey()) {
      _showDayCompletionWarning();
      return;
    }

    if (status == 'focus') {
      context.push(
        '/focus',
        extra: {
          'taskId': task.id,
          'taskTitle': task.title,
          'durationMinutes': task.durationMinutes,
        },
      );
      return;
    }

    final focusState = ref.read(focusTimerProvider);
    final isThisTask = focusState.taskTitle == task.title;
    final isTimerPaused =
        focusState.remainingSeconds > 0 &&
        focusState.remainingSeconds < focusState.totalSeconds;

    // Redirect if timer is actively running, OR if it's paused for THIS task.
    if (focusState.isRunning || (isThisTask && isTimerPaused)) {
      context.push(
        '/focus',
        extra: {
          'taskId': task.id,
          'taskTitle': task.title,
          'durationMinutes': task.durationMinutes,
        },
      );
      return;
    }

    if (status == 'toggle') {
      ref.read(sessionsProvider.notifier).toggleTask(task.id);
    } else {
      ref
          .read(sessionsProvider.notifier)
          .setExplicitTaskStatus(task.id, status);
    }
  }

  void _toggleBonus(String taskId) {
    HapticFeedback.lightImpact();
    final selectedDateStr = ref.read(sessionsProvider).value?.selectedDate ?? dateService.todayKey();
    if (selectedDateStr != dateService.todayKey()) {
      _showDayCompletionWarning();
      return;
    }
    ref.read(sessionsProvider.notifier).toggleBonus(taskId);
  }

  void _showDayCompletionWarning() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
            const SizedBox(width: 8),
            Text(
              'Action Not Allowed',
              style: AppTypography.body(size: 18, weight: FontWeight.w700),
            ),
          ],
        ),
        content: Text(
          'You can only complete or modify task progress for today. '
          'To log progress, please switch back to the current day.',
          style: AppTypography.body(size: 14, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'OK',
              style: AppTypography.body(
                size: 14,
                weight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateString(String dateKey) {
    final date = DateTime.tryParse(dateKey) ?? DateTime.now();
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June', 
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final weekday = weekdays[date.weekday - 1];
    final month = months[date.month - 1];
    return '$weekday, $month ${date.day}';
  }

  Future<void> _pickSessionsDate() async {
    final stateVal = ref.read(sessionsProvider).value;
    final currentDateKey = stateVal?.selectedDate ?? dateService.todayKey();
    final currentDate = DateTime.tryParse(currentDateKey) ?? DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final key = dateService.keyFor(picked);
      await ref.read(sessionsProvider.notifier).changeDate(key);
    }
  }

  void _editTask(Task task, Session session) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          AddTaskSheet(defaultSession: session, existingTask: task),
    );
  }

  void _showTaskOptions(Task task, Session session) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          bottom:
              MediaQuery.of(ctx).padding.bottom + kBottomNavigationBarHeight,
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceRaised,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              InkWell(
                onTap: () {
                  Navigator.pop(ctx);
                  _editTask(task, session);
                },
                child: Container(
                  height: 56,
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.edit_rounded,
                        color: AppColors.textPrimary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text('Edit', style: AppTypography.body(size: 16)),
                    ],
                  ),
                ),
              ),
              InkWell(
                onTap: () {
                  Navigator.pop(ctx);
                  ref
                      .read(sessionsProvider.notifier)
                      .deleteCustomTask(task.id, session.id);
                },
                child: Container(
                  height: 56,
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.moodLow,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Delete',
                        style: AppTypography.body(
                          size: 16,
                          color: AppColors.moodLow,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              InkWell(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  height: 56,
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.close_rounded,
                        color: AppColors.textPrimary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text('Cancel', style: AppTypography.body(size: 16)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(completionPctProvider, (previous, next) {
      if (previous != null && previous != 100 && next == 100) {
        _confettiController.play();
        HapticFeedback.heavyImpact();
      }
    });

    final sessionsAsync = ref.watch(sessionsProvider);
    final selectedDateStr = sessionsAsync.value?.selectedDate ?? dateService.todayKey();
    final sessions = sessionsAsync.value?.sessions ?? _sessions;
    final safeIndex = _currentIndex.clamp(0, sessions.length - 1);
    final session = sessions[safeIndex];
    final taskStates = sessionsAsync.value?.taskStates ?? {};
    final taskStatus = sessionsAsync.value?.dailyState.taskStatus ?? {};
    final bonusStates = sessionsAsync.value?.bonusStates ?? {};



    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onLongPress: () {
                    HapticFeedback.mediumImpact();
                    _pickSessionsDate();
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    'Sessions',
                                    style: AppTypography.screenTitle(
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  if (selectedDateStr != dateService.todayKey()) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'Archived',
                                        style: AppTypography.body(
                                          size: 10,
                                          weight: FontWeight.w700,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                if (selectedDateStr != dateService.todayKey()) ...[
                                  TextButton.icon(
                                    onPressed: () {
                                      ref.read(sessionsProvider.notifier).changeDate(dateService.todayKey());
                                    },
                                    icon: Icon(Icons.today_rounded, size: 16, color: AppColors.primary),
                                    label: Text(
                                      'Today',
                                      style: AppTypography.body(
                                        size: 12,
                                        weight: FontWeight.w600,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                GestureDetector(
                                  onTap: () {
                                    showModalBottomSheet(
                                      context: context,
                                      useRootNavigator: true,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (context) =>
                                          AddTaskSheet(defaultSession: session),
                                    );
                                  },
                                  behavior: HitTestBehavior.opaque,
                                  child: Padding(
                                    padding: const EdgeInsets.all(4.0),
                                    child: Icon(
                                      Icons.add,
                                      color: AppColors.textPrimary,
                                      size: 28,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          selectedDateStr == dateService.todayKey()
                              ? 'Plan your day. Stay consistent.'
                              : 'Viewing: ${_formatDateString(selectedDateStr)}',
                          style: AppTypography.body(
                            size: 13,
                            color: selectedDateStr == dateService.todayKey()
                                ? AppColors.textSecondary
                                : AppColors.primary,
                            weight: selectedDateStr == dateService.todayKey()
                                ? FontWeight.normal
                                : FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 16),
                SizedBox(
                  height: 38,
                  child: SingleChildScrollView(
                    controller: _pillScrollController,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(sessions.length, (i) {
                        final s = sessions[i];
                        final validTasks = s.tasks
                            .where((t) => !t.isBreak)
                            .toList();
                        final doneCount = validTasks
                            .where((t) => taskStates[t.id] == true)
                            .length;
                        final skippedCount = validTasks
                            .where((t) => taskStatus[t.id] == 'skipped')
                            .length;
                        final total = validTasks.length - skippedCount;
                        final percent = total <= 0 ? 0.0 : doneCount / total;

                        final now = TimeOfDay.now();
                        final nowMin = now.hour * 60 + now.minute;
                        bool isFuture = false;
                        final range = s.timeRange
                            .split(RegExp(r'\s*[-\u2013\u2014]\s*'))
                            .map((p) => p.trim())
                            .toList();
                        if (range.isNotEmpty) {
                          final startMin = _parseTime(range[0]);
                          isFuture = nowMin < startMin;
                        }

                        return Padding(
                          padding: EdgeInsets.only(
                            right: i < sessions.length - 1 ? 8.0 : 0.0,
                          ),
                          child: _SessionPill(
                            session: s,
                            isSelected: i == safeIndex,
                            percent: percent,
                            isFuture: isFuture,
                            onTap: () => _onPillTap(i),
                          ),
                        );
                      }),
                    ),
                  ),
                ),

                SizedBox(height: 4),
                Divider(height: 1, color: AppColors.border),


                Expanded(
                  child: sessionsAsync.when(
                    loading: () => Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                    error: (e, _) => Center(
                      child: Text(
                        'Error loading sessions',
                        style: AppTypography.body(color: AppColors.textMuted),
                      ),
                    ),
                    data: (_) => PageView.builder(
                      controller: _pageController,
                      physics: const BouncingScrollPhysics(),
                      onPageChanged: _onPageChanged,
                      itemCount: sessions.length,
                      itemBuilder: (context, i) => _SessionPage(
                        session: sessions[i],
                        taskStates: taskStates,
                        taskStatus:
                            sessionsAsync.value?.dailyState.taskStatus ?? {},
                        bonusStates: bonusStates,
                        onToggleTask: (task) => _setTaskStatus(task, 'toggle'),
                        onSetStatus: _setTaskStatus,
                        onToggleBonus: _toggleBonus,
                        onLongPressTask: (task) =>
                            _showTaskOptions(task, sessions[i]),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            emissionFrequency: 0.05,
            numberOfParticles: 20,
            maxBlastForce: 20,
            minBlastForce: 8,
            gravity: 0.3,
            colors: [
              AppColors.complete,
              Colors.blue,
              Colors.orange,
              Colors.purple,
              Colors.pink,
            ],
          ),
        ),
      ],
    );
  }
}

// Session Pill

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

    if (isFuture) {
      bgColor = Colors.white;
      textColor = AppColors.textSecondary;
      borderColor = isSelected ? AppColors.primary : AppColors.border;
    } else {
      if (percent >= 1.0) {
        bgColor = AppColors.complete; // Stage 5
        textColor = Colors.white;
        borderColor = isSelected ? AppColors.textPrimary : AppColors.complete;
      } else if (percent >= 0.67) {
        bgColor = Color(0xFF3B82F6); // Stage 4
        textColor = Colors.white;
        borderColor = isSelected ? AppColors.textPrimary : Color(0xFF3B82F6);
      } else if (percent >= 0.34) {
        bgColor = Color(0xFF93C5FD); // Stage 3
        textColor = AppColors.textPrimary;
        borderColor = isSelected ? AppColors.textPrimary : Color(0xFF93C5FD);
      } else if (percent > 0.0) {
        bgColor = Color(0xFFDBEAFE); // Stage 2
        textColor = AppColors.textPrimary;
        borderColor = isSelected ? AppColors.textPrimary : Color(0xFFDBEAFE);
      } else {
        bgColor = Colors.white; // Stage 1
        textColor = AppColors.textPrimary;
        borderColor = isSelected ? AppColors.textPrimary : AppColors.border;
      }
    }

    final is100 = percent == 1.0;
    final displayName = is100 ? 'Completed' : session.name;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: isSelected ? 2.0 : 1.5),
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
                displayName,
                style: AppTypography.body(
                  size: 12,
                  weight: isSelected ? FontWeight.w700 : FontWeight.w500,
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

// Session Page  (one per session in PageView)

class _SessionPage extends StatelessWidget {
  const _SessionPage({
    required this.session,
    required this.taskStates,
    required this.taskStatus,
    required this.bonusStates,
    required this.onToggleTask,
    required this.onSetStatus,
    required this.onToggleBonus,
    required this.onLongPressTask,
  });

  final Session session;
  final Map<String, bool> taskStates;
  final Map<String, String> taskStatus;
  final Map<String, bool> bonusStates;
  final ValueChanged<Task> onToggleTask;
  final void Function(Task, String) onSetStatus;
  final ValueChanged<String> onToggleBonus;
  final ValueChanged<Task> onLongPressTask;

  @override
  Widget build(BuildContext context) {
    final validTasks = session.tasks.where((t) => !t.isBreak).toList();
    final doneCount = validTasks.where((t) => taskStates[t.id] == true).length;
    final skippedCount = validTasks
        .where((t) => taskStatus[t.id] == 'skipped')
        .length;
    final totalValid = validTasks.length - skippedCount;
    final isAllDone = totalValid > 0 && doneCount == totalValid;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
      children: [
        if (isAllDone) ...[
          _SessionCompleteBanner(sessionName: session.name),
          SizedBox(height: 24),
        ],
        ...session.tasks.asMap().entries.map((entry) {
          final index = entry.key;
          final task = entry.value;
          return _TaskCard(
            task: task,
            isDone: taskStates[task.id] ?? false,
            taskStatus: taskStatus[task.id] ?? 'none',
            isFirst: index == 0,
            isLast: index == session.tasks.length - 1,
            onToggle: () => onToggleTask(task),
            onSetStatus: onSetStatus,
            onLongPress: () => onLongPressTask(task),
          );
        }),
      ],
    );
  }
}

// Timeline Painter

class _TimelinePainter extends CustomPainter {
  final bool isFirst;
  final bool isLast;

  _TimelinePainter({this.isFirst = false, this.isLast = false});

  @override
  void paint(Canvas canvas, Size size) {
    if (isFirst && isLast) return;

    final paint = Paint()
      ..color = Color(0xFFE5E7EB)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final double dashWidth = 4, dashSpace = 4;
    double startY = isFirst ? size.height / 2 : 0;
    final double endY = isLast ? size.height / 2 : size.height;

    while (startY < endY) {
      canvas.drawLine(
        Offset(size.width / 2, startY),
        Offset(size.width / 2, (startY + dashWidth).clamp(0.0, endY)),
        paint,
      );
      startY += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter oldDelegate) =>
      oldDelegate.isFirst != isFirst || oldDelegate.isLast != isLast;
}

// Task Card (Timeline Style)

class _TaskCard extends StatefulWidget {
  const _TaskCard({
    required this.task,
    required this.isDone,
    required this.taskStatus,
    required this.isFirst,
    required this.isLast,
    required this.onToggle,
    required this.onSetStatus,
    required this.onLongPress,
  });

  final Task task;
  final bool isDone;
  final String taskStatus;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onToggle;
  final void Function(Task, String) onSetStatus;
  final VoidCallback onLongPress;

  @override
  State<_TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<_TaskCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    if (_isExpanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  void _closeExpanded() {
    if (_isExpanded) {
      setState(() => _isExpanded = false);
      _controller.reverse();
    }
  }

  IconData _getIconData(String name) {
    const Map<String, IconData> icons = {
      'star': Icons.star_rounded,
      'sun': Icons.wb_sunny_rounded,
      'bed': Icons.bed_rounded,
      'cup': Icons.local_cafe_rounded,
      'book': Icons.menu_book_rounded,
      'walk': Icons.directions_walk_rounded,
      'workout': Icons.fitness_center_rounded,
      'group': Icons.group_rounded,
      'meditation': Icons.self_improvement_rounded,
      'laptop': Icons.laptop_mac_rounded,
      'eat': Icons.restaurant_rounded,
      'shower': Icons.shower_rounded,
      'shop': Icons.shopping_cart_rounded,
      'drive': Icons.drive_eta_rounded,
      'prayer': Icons.mosque_rounded,
      'job': Icons.work_outline_rounded,
      'english': Icons.translate_rounded,
      'interview': Icons.co_present_rounded,
      'family': Icons.family_restroom_rounded,
    };
    return icons[name] ?? Icons.star_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = widget.task.time.toLowerCase().trim();
    String formattedTime = timeStr;

    if (timeStr.contains('am') || timeStr.contains('pm')) {
      final isPm = timeStr.contains('pm');
      var t = timeStr.replaceAll('am', '').replaceAll('pm', '').trim();
      final parts = t.split(':');
      if (parts.length == 2) {
        int h = int.tryParse(parts[0]) ?? 0;
        final m = parts[1];
        if (isPm && h < 12) h += 12;
        if (!isPm && h == 12) h = 0;
        formattedTime = '${h.toString().padLeft(2, '0')}:$m';
      } else {
        formattedTime = t;
      }
    } else {
      final parts = timeStr.split(':');
      if (parts.length == 2) {
        int h = int.tryParse(parts[0]) ?? 0;
        formattedTime = '${h.toString().padLeft(2, '0')}:${parts[1]}';
      }
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 50,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                formattedTime,
                style: AppTypography.body(
                  size: 12,
                  weight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 32,
            child: CustomPaint(
              painter: _TimelinePainter(
                isFirst: widget.isFirst,
                isLast: widget.isLast,
              ),
              child: Align(
                alignment: Alignment.center,
                child: GestureDetector(
                  onTap: widget.task.isBreak ? null : widget.onToggle,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.task.isBreak
                          ? Colors.black
                          : widget.isDone
                              ? widget.taskStatus == 'late'
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFF4ADE80)
                              : widget.taskStatus == 'skipped'
                                  ? const Color(0xFFEF4444)
                                  : Colors.white,
                      border: (widget.isDone ||
                              widget.task.isBreak ||
                              widget.taskStatus == 'skipped')
                          ? null
                          : Border.all(color: const Color(0xFFD1D5DB), width: 1.5),
                    ),
                    child: widget.task.isBreak
                        ? null
                        : widget.isDone
                            ? const Icon(Icons.check, size: 10, color: Colors.white)
                            : widget.taskStatus == 'skipped'
                                ? const Icon(Icons.close, size: 10, color: Colors.white)
                                : null,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: GestureDetector(
                onLongPress: () {
                  HapticFeedback.mediumImpact();
                  widget.onLongPress();
                },
                onTap: widget.task.isBreak
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        _toggleExpanded();
                      },
                child: Container(
                  clipBehavior: Clip.hardEdge,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFF3F4F6),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _getIconData(widget.task.iconName),
                              size: 16,
                              color: widget.isDone && !widget.task.isBreak
                                  ? Color(0xFF9CA3AF)
                                  : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      widget.task.title,
                                      style:
                                          AppTypography.body(
                                            size: 14,
                                            weight: FontWeight.w600,
                                            color:
                                                (widget.isDone ||
                                                        widget.taskStatus ==
                                                            'skipped') &&
                                                    !widget.task.isBreak
                                                ? Color(0xFF9CA3AF)
                                                : AppColors.textPrimary,
                                          ).copyWith(
                                            decoration:
                                                (widget.isDone ||
                                                        widget.taskStatus ==
                                                            'skipped') &&
                                                    !widget.task.isBreak
                                                ? TextDecoration.lineThrough
                                                : TextDecoration.none,
                                          ),
                                    ),
                                    if (widget.task.isKeyTask) ...[
                                      const SizedBox(width: 6),
                                      const Icon(
                                        Icons.star_rounded,
                                        size: 16,
                                        color: Color(0xFFF59E0B),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 2.0),
                            child: Text(
                              '${widget.task.durationMinutes}m',
                              style: AppTypography.body(
                                size: 12,
                                weight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (!widget.task.isBreak)
                        SizeTransition(
                          sizeFactor: _animation,
                          axisAlignment: -1.0,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: Column(
                              children: [
                                Container(
                                  height: 1,
                                  width: double.infinity,
                                  color: AppColors.border.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    if (widget.task.hasSessionTimer)
                                      _TrayButton(
                                        icon: Icons.timer_outlined,
                                        label: 'Focus',
                                        color: AppColors.textPrimary,
                                        onTap: () {
                                          _closeExpanded();
                                          widget.onSetStatus(
                                            widget.task,
                                            'focus',
                                          );
                                        },
                                      ),
                                    _TrayButton(
                                      icon: Icons.check_circle_rounded,
                                      label: 'On Time',
                                      color: const Color(0xFF4ade80),
                                      onTap: () {
                                        _closeExpanded();
                                        widget.onSetStatus(
                                          widget.task,
                                          'on_time',
                                        );
                                      },
                                    ),
                                    _TrayButton(
                                      icon: Icons.access_time_filled_rounded,
                                      label: 'Delayed',
                                      color: const Color(0xFFF59E0B),
                                      onTap: () {
                                        _closeExpanded();
                                        widget.onSetStatus(widget.task, 'late');
                                      },
                                    ),
                                    _TrayButton(
                                      icon: Icons.skip_next_rounded,
                                      label: 'Skip',
                                      color: const Color(0xFFEF4444),
                                      onTap: () {
                                        _closeExpanded();
                                        widget.onSetStatus(
                                          widget.task,
                                          'skipped',
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
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
}

class _TrayButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _TrayButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }
}

// Session Complete Banner

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
          border: Border.all(color: AppColors.complete.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: AppColors.complete,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Complete!',
                    style: AppTypography.body(
                      size: 14,
                      weight: FontWeight.w600,
                      color: Color(0xFF166634),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
