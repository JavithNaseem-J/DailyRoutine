import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../core/models/quick_task.dart';
import '../../core/services/hive_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../main.dart' show deviceId;

class EisenhowerBoardScreen extends StatefulWidget {
  const EisenhowerBoardScreen({super.key});

  @override
  State<EisenhowerBoardScreen> createState() => _EisenhowerBoardScreenState();
}

class _EisenhowerBoardScreenState extends State<EisenhowerBoardScreen> {
  List<QuickTask> _allTasks = [];
  bool _loading = true;
  int _hoveredColumnIndex = -1;

  // Controllers for adding tasks in each of the 4 columns
  final List<TextEditingController> _addControllers =
      List.generate(4, (_) => TextEditingController());

  // Definition of the 4 columns
  final List<_QuadrantMeta> _columns = [
    _QuadrantMeta(
      label: 'Do First',
      description: 'Urgent & Important',
      icon: Icons.flash_on_rounded,
      color: const Color(0xFFF87171), // Rose/Red
      urgency: true,
      important: true,
    ),
    _QuadrantMeta(
      label: 'Schedule',
      description: 'Not Urgent & Important',
      icon: Icons.calendar_today_rounded,
      color: const Color(0xFFF59E0B), // Amber/Yellow
      urgency: false,
      important: true,
    ),
    _QuadrantMeta(
      label: 'Delegate',
      description: 'Urgent & Not Important',
      icon: Icons.people_outline_rounded,
      color: const Color(0xFF38BDF8), // Sky Blue
      urgency: true,
      important: false,
    ),
    _QuadrantMeta(
      label: 'Eliminate',
      description: 'Not Urgent & Not Important',
      icon: Icons.delete_outline_rounded,
      color: const Color(0xFF9CA3AF), // Slate Gray
      urgency: false,
      important: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  @override
  void dispose() {
    for (final c in _addControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _loadTasks() {
    // 1. Read locally from Hive
    setState(() {
      _allTasks = hiveService.readQuickTasks('global');
      _loading = false;
    });

    // 2. Fetch from Supabase and sync
    supabaseService.fetchQuickTasks('global', deviceId).then((remote) {
      if (!mounted) return;
      final local = hiveService.readQuickTasks('global');
      
      // Deduplicate/merge
      final Map<String, QuickTask> merged = {for (var t in local) t.id: t};
      for (final r in remote) {
        if (!merged.containsKey(r.id) || r.createdAt.isAfter(merged[r.id]!.createdAt)) {
          merged[r.id] = r;
        }
      }
      
      final cleaned = merged.values.toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      setState(() => _allTasks = cleaned);
      hiveService.writeQuickTasks('global', cleaned);
    }).catchError((_) {});
  }

  void _addTask(String title, bool isUrgent, bool isImportant, int colIndex) {
    if (title.trim().isEmpty) return;
    HapticFeedback.mediumImpact();

    final task = QuickTask(
      id: const Uuid().v4(),
      date: 'global',
      title: title.trim(),
      isUrgent: isUrgent,
      isImportant: isImportant,
      done: false,
    );

    final updated = [..._allTasks, task];
    setState(() => _allTasks = updated);
    hiveService.writeQuickTasks('global', updated);
    supabaseService.upsertQuickTask(task, deviceId).catchError((_) {});

    _addControllers[colIndex].clear();
  }

  void _toggleTask(String id) {
    HapticFeedback.lightImpact();
    final idx = _allTasks.indexWhere((t) => t.id == id);
    if (idx == -1) return;

    final updatedTask = _allTasks[idx].copyWith(done: !_allTasks[idx].done);
    final updatedList = [..._allTasks]..[idx] = updatedTask;

    setState(() => _allTasks = updatedList);
    hiveService.writeQuickTasks('global', updatedList);
    supabaseService.upsertQuickTask(updatedTask, deviceId).catchError((_) {});
  }

  void _deleteTask(String id) {
    HapticFeedback.heavyImpact();
    final idx = _allTasks.indexWhere((t) => t.id == id);
    if (idx == -1) return;

    final task = _allTasks[idx];
    final updatedList = [..._allTasks]..removeAt(idx);

    setState(() => _allTasks = updatedList);
    hiveService.writeQuickTasks('global', updatedList);
    supabaseService.deleteQuickTask(task.id).catchError((_) {});
  }

  void _updateTask(QuickTask updated) {
    final idx = _allTasks.indexWhere((t) => t.id == updated.id);
    if (idx == -1) return;

    final updatedList = [..._allTasks]..[idx] = updated;
    setState(() => _allTasks = updatedList);
    hiveService.writeQuickTasks('global', updatedList);
    supabaseService.upsertQuickTask(updated, deviceId).catchError((_) {});
  }

  void _moveTask(QuickTask task, bool isUrgent, bool isImportant) {
    final updated = task.copyWith(
      isUrgent: isUrgent,
      isImportant: isImportant,
    );
    _updateTask(updated);
  }

  void _cyclePriority(QuickTask task) {
    HapticFeedback.selectionClick();
    final current = task.priority;
    String? next;
    if (current == null) {
      next = 'P1';
    } else if (current == 'P1') {
      next = 'P2';
    } else if (current == 'P2') {
      next = 'P3';
    } else {
      next = null;
    }
    _updateTask(task.copyWith(priority: next));
  }

  Future<void> _selectDeadline(BuildContext context, QuickTask task) async {
    HapticFeedback.selectionClick();
    final currentDeadline = task.deadline != null ? DateTime.tryParse(task.deadline!) : null;
    final picked = await showDatePicker(
      context: context,
      initialDate: currentDeadline ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.cardSurface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final deadlineStr = picked.toIso8601String().substring(0, 10);
      _updateTask(task.copyWith(deadline: deadlineStr));
    }
  }

  void _showDelegateDialog(BuildContext context, QuickTask task) {
    HapticFeedback.selectionClick();
    final ctl = TextEditingController(text: task.delegatee);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.cardSurface,
          title: Text(
            'Delegate Task',
            style: AppTypography.body(size: 16, weight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          content: TextField(
            controller: ctl,
            autofocus: true,
            style: TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Assignee name',
              hintStyle: TextStyle(color: AppColors.textMuted),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.textMuted)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () {
                _updateTask(task.copyWith(delegatee: ctl.text.trim().isEmpty ? null : ctl.text.trim()));
                Navigator.pop(context);
              },
              child: Text('Assign', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showMoveMenu(BuildContext context, QuickTask task) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Move Task to Quadrant',
                  style: AppTypography.body(size: 15, weight: FontWeight.w700, color: AppColors.textSecondary),
                ),
              ),
              const Divider(height: 1),
              ...List.generate(4, (i) {
                final col = _columns[i];
                final isCurrent = task.isUrgent == col.urgency && task.isImportant == col.important;
                return ListTile(
                  leading: Icon(col.icon, color: col.color),
                  title: Text(col.label, style: TextStyle(color: isCurrent ? AppColors.primary : AppColors.textPrimary)),
                  trailing: isCurrent ? Icon(Icons.check, color: AppColors.primary) : null,
                  onTap: () {
                    _moveTask(task, col.urgency, col.important);
                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final totalCompleted = _allTasks.where((t) => t.done).length;
    final totalCount = _allTasks.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: AppColors.surfaceRaised,
            child: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary, size: 20),
              onPressed: () => context.pop(),
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Eisenhower Matrix Board',
              style: AppTypography.body(size: 18, weight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 2),
            Text(
              '$totalCompleted of $totalCount completed',
              style: AppTypography.body(size: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final columnWidth = constraints.maxWidth * 0.82;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(4, (colIndex) {
                final col = _columns[colIndex];
                final qTasks = _allTasks
                    .where((t) => t.isUrgent == col.urgency && t.isImportant == col.important)
                    .toList();

                final completedQ = qTasks.where((t) => t.done).length;
                final totalQ = qTasks.length;

                final isHovered = _hoveredColumnIndex == colIndex;

                return Container(
                  width: columnWidth,
                  margin: const EdgeInsets.only(right: 16),
                  child: DragTarget<QuickTask>(
                    onWillAcceptWithDetails: (details) => true,
                    onMove: (details) {
                      if (_hoveredColumnIndex != colIndex) {
                        setState(() => _hoveredColumnIndex = colIndex);
                      }
                    },
                    onLeave: (data) {
                      if (_hoveredColumnIndex == colIndex) {
                        setState(() => _hoveredColumnIndex = -1);
                      }
                    },
                    onAcceptWithDetails: (details) {
                      HapticFeedback.mediumImpact();
                      setState(() => _hoveredColumnIndex = -1);
                      _moveTask(details.data, col.urgency, col.important);
                    },
                    builder: (context, candidateData, rejectedData) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.cardSurface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isHovered
                                ? col.color
                                : col.color.withValues(alpha: 0.15),
                            width: isHovered ? 2.5 : 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isHovered
                                  ? col.color.withValues(alpha: 0.15)
                                  : Colors.black.withValues(alpha: 0.04),
                              blurRadius: isHovered ? 20 : 10,
                              spreadRadius: isHovered ? 2 : 0,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Column Header
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: col.color.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(col.icon, color: col.color, size: 18),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        col.label,
                                        style: AppTypography.body(
                                          size: 14,
                                          weight: FontWeight.w800,
                                          color: col.color,
                                        ),
                                      ),
                                      Text(
                                        col.description,
                                        style: AppTypography.body(
                                          size: 10,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceRaised,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '$completedQ/$totalQ',
                                    style: AppTypography.mono(
                                      size: 10,
                                      weight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Column list of items
                            Expanded(
                              child: qTasks.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            col.icon,
                                            size: 32,
                                            color: AppColors.textMuted.withValues(alpha: 0.3),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Drag tasks here',
                                            style: AppTypography.body(
                                              size: 11,
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : ListView.separated(
                                      physics: const AlwaysScrollableScrollPhysics(),
                                      itemCount: qTasks.length,
                                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                                      itemBuilder: (context, index) {
                                        final task = qTasks[index];
                                        return LongPressDraggable<QuickTask>(
                                          data: task,
                                          feedback: Material(
                                            color: Colors.transparent,
                                            child: Transform.rotate(
                                              angle: 0.03,
                                              child: Container(
                                                width: columnWidth - 32,
                                                padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: AppColors.surfaceRaised,
                                                  borderRadius: BorderRadius.circular(16),
                                                  border: Border.all(color: col.color, width: 1.5),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black.withValues(alpha: 0.15),
                                                      blurRadius: 12,
                                                      spreadRadius: 2,
                                                      offset: const Offset(0, 4),
                                                    ),
                                                  ],
                                                ),
                                                child: Text(
                                                  task.title,
                                                  style: AppTypography.body(
                                                    size: 13,
                                                    weight: FontWeight.w600,
                                                    color: AppColors.textPrimary,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          childWhenDragging: Opacity(
                                            opacity: 0.3,
                                            child: Container(
                                              height: 60,
                                              decoration: BoxDecoration(
                                                color: Colors.transparent,
                                                borderRadius: BorderRadius.circular(16),
                                                border: Border.all(
                                                  color: col.color.withValues(alpha: 0.3),
                                                  style: BorderStyle.solid,
                                                  width: 1.5,
                                                ),
                                              ),
                                            ),
                                          ),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: AppColors.surfaceRaised,
                                              borderRadius: BorderRadius.circular(16),
                                              border: Border.all(
                                                color: task.done
                                                    ? Colors.transparent
                                                    : col.color.withValues(alpha: 0.08),
                                                width: 1.0,
                                              ),
                                            ),
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Checkbox(
                                                      value: task.done,
                                                      activeColor: col.color,
                                                      checkColor: Colors.white,
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      onChanged: (_) => _toggleTask(task.id),
                                                    ),
                                                    Expanded(
                                                      child: Text(
                                                        task.title,
                                                        style: AppTypography.body(
                                                          size: 13,
                                                          weight: FontWeight.w600,
                                                          color: task.done
                                                              ? AppColors.textMuted
                                                              : AppColors.textPrimary,
                                                        ).copyWith(
                                                          decoration: task.done
                                                              ? TextDecoration.lineThrough
                                                              : TextDecoration.none,
                                                        ),
                                                      ),
                                                    ),
                                                    IconButton(
                                                      icon: Icon(
                                                        Icons.more_horiz_rounded,
                                                        size: 18,
                                                        color: AppColors.textSecondary,
                                                      ),
                                                      onPressed: () => _showMoveMenu(context, task),
                                                    ),
                                                  ],
                                                ),
                                                // Badges Section (Priority, Deadline, Delegatee)
                                                if (!task.done) ...[
                                                  Padding(
                                                    padding: const EdgeInsets.only(left: 36, bottom: 4),
                                                    child: Wrap(
                                                      spacing: 6,
                                                      runSpacing: 4,
                                                      children: [
                                                        // 1. Do First - Priority Badge
                                                        if (colIndex == 0)
                                                          GestureDetector(
                                                            onTap: () => _cyclePriority(task),
                                                            child: Container(
                                                              padding: const EdgeInsets.symmetric(
                                                                  horizontal: 8, vertical: 3),
                                                              decoration: BoxDecoration(
                                                                color: task.priority == 'P1'
                                                                    ? col.color
                                                                    : task.priority == 'P2'
                                                                        ? col.color.withValues(alpha: 0.65)
                                                                        : task.priority == 'P3'
                                                                            ? col.color.withValues(alpha: 0.35)
                                                                            : AppColors.cardSurface,
                                                                borderRadius: BorderRadius.circular(6),
                                                              ),
                                                              child: Text(
                                                                task.priority ?? 'Priority',
                                                                style: AppTypography.body(
                                                                  size: 10,
                                                                  weight: FontWeight.bold,
                                                                  color: task.priority != null
                                                                      ? Colors.white
                                                                      : AppColors.textSecondary,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        // 2. Schedule - Deadline Badge
                                                        if (colIndex == 1)
                                                          GestureDetector(
                                                            onTap: () => _selectDeadline(context, task),
                                                            child: Container(
                                                              padding: const EdgeInsets.symmetric(
                                                                  horizontal: 8, vertical: 3),
                                                              decoration: BoxDecoration(
                                                                color: task.deadline != null
                                                                    ? col.color.withValues(alpha: 0.2)
                                                                    : AppColors.cardSurface,
                                                                borderRadius: BorderRadius.circular(6),
                                                              ),
                                                              child: Row(
                                                                mainAxisSize: MainAxisSize.min,
                                                                children: [
                                                                  Icon(
                                                                    Icons.access_time_rounded,
                                                                    size: 10,
                                                                    color: task.deadline != null
                                                                        ? col.color
                                                                        : AppColors.textSecondary,
                                                                  ),
                                                                  const SizedBox(width: 4),
                                                                  Text(
                                                                    task.deadline ?? 'Plan Date',
                                                                    style: AppTypography.body(
                                                                      size: 10,
                                                                      weight: task.deadline != null
                                                                          ? FontWeight.bold
                                                                          : FontWeight.normal,
                                                                      color: task.deadline != null
                                                                          ? col.color
                                                                          : AppColors.textSecondary,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        // 3. Delegate - Delegatee Badge
                                                        if (colIndex == 2)
                                                          GestureDetector(
                                                            onTap: () => _showDelegateDialog(context, task),
                                                            child: Container(
                                                              padding: const EdgeInsets.symmetric(
                                                                  horizontal: 8, vertical: 3),
                                                              decoration: BoxDecoration(
                                                                color: task.delegatee != null
                                                                    ? col.color.withValues(alpha: 0.2)
                                                                    : AppColors.cardSurface,
                                                                borderRadius: BorderRadius.circular(6),
                                                              ),
                                                              child: Row(
                                                                mainAxisSize: MainAxisSize.min,
                                                                children: [
                                                                  Icon(
                                                                    Icons.person_pin_rounded,
                                                                    size: 10,
                                                                    color: task.delegatee != null
                                                                        ? col.color
                                                                        : AppColors.textSecondary,
                                                                  ),
                                                                  const SizedBox(width: 4),
                                                                  Text(
                                                                    task.delegatee ?? 'Assignee',
                                                                    style: AppTypography.body(
                                                                      size: 10,
                                                                      weight: task.delegatee != null
                                                                          ? FontWeight.bold
                                                                          : FontWeight.normal,
                                                                      color: task.delegatee != null
                                                                          ? col.color
                                                                          : AppColors.textSecondary,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        // 4. Eliminate - Quick Delete Action
                                                        if (colIndex == 3)
                                                          GestureDetector(
                                                            onTap: () => _deleteTask(task.id),
                                                            child: Container(
                                                              padding: const EdgeInsets.symmetric(
                                                                  horizontal: 8, vertical: 3),
                                                              decoration: BoxDecoration(
                                                                color: AppColors.cardSurface,
                                                                borderRadius: BorderRadius.circular(6),
                                                              ),
                                                              child: Row(
                                                                mainAxisSize: MainAxisSize.min,
                                                                children: [
                                                                  Icon(
                                                                    Icons.delete_forever_rounded,
                                                                    size: 10,
                                                                    color: AppColors.textSecondary,
                                                                  ),
                                                                  const SizedBox(width: 4),
                                                                  Text(
                                                                    'Delete',
                                                                    style: AppTypography.body(
                                                                      size: 10,
                                                                      color: AppColors.textSecondary,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                            const SizedBox(height: 12),
                            // Quick Add Row inside the Column
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _addControllers[colIndex],
                                    style: AppTypography.body(size: 12, color: AppColors.textPrimary),
                                    decoration: InputDecoration(
                                      hintText: 'Add to ${col.label}...',
                                      hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 11),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      filled: true,
                                      fillColor: AppColors.surfaceRaised,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                    onSubmitted: (val) => _addTask(val, col.urgency, col.important, colIndex),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: col.color,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.add, color: Colors.white, size: 16),
                                    onPressed: () => _addTask(
                                      _addControllers[colIndex].text,
                                      col.urgency,
                                      col.important,
                                      colIndex,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              }),
            ),
          );
        },
      ),
    );
  }
}

class _QuadrantMeta {
  _QuadrantMeta({
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
    required this.urgency,
    required this.important,
  });

  final String label;
  final String description;
  final IconData icon;
  final Color color;
  final bool urgency;
  final bool important;
}
