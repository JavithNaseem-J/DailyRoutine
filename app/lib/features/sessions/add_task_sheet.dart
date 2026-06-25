import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/session_data.dart';
import '../../core/models/session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../sessions/providers/sessions_provider.dart';
import '../../core/services/hive_service.dart';


class AddTaskSheet extends ConsumerStatefulWidget {
  const AddTaskSheet({super.key, required this.defaultSession, this.existingTask});

  final Session defaultSession;
  final Task? existingTask;

  @override
  ConsumerState<AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends ConsumerState<AddTaskSheet> {
  late Session _selectedSession;
  final _titleController = TextEditingController();
  bool _isBreak = false;
  bool _hasSessionTimer = false;
  bool _isKeyTask = false;
  String _selectedIconName = 'star';

  /// Selected weekdays: 1=Mon … 7=Sun. Empty means every day.
  late List<int> _selectedWeekdays;

  StateOfMind? _selectedStateOfMind;
  bool _isUrgent = false;
  String? _selectedPriority;

  static const Map<String, IconData> _appIcons = {
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

  DateTime _selectedTime = DateTime.now();
  Duration _selectedDuration = const Duration(minutes: 15);
  DateTime? _minTime;
  DateTime? _maxTime;

  late List<Session> _availableSessions;

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.existingTask?.title ?? '';
    _selectedSession = widget.defaultSession;
    _availableSessions = SessionData.sessionsForToday
        .where((s) => s.id != 'key_tasks')
        .toList();

    // Default weekdays: all days (empty = every day)
    _selectedWeekdays = [];
    if (widget.defaultSession.id == 'saturday') {
      _selectedWeekdays = [DateTime.saturday];
    } else if (widget.defaultSession.id == 'sunday') {
      _selectedWeekdays = [DateTime.sunday];
    }

    // Ensure the default session is in the list
    if (!_availableSessions.any((s) => s.id == _selectedSession.id)) {
      _selectedSession = _availableSessions.first;
    }

    // Override session if editing
    if (widget.existingTask != null) {
      _selectedSession = _availableSessions.firstWhere(
        (s) => s.id == widget.existingTask!.sessionId,
        orElse: () => _selectedSession,
      );
    }

    _updateTimeBounds();

    if (widget.existingTask != null) {
      final parts = widget.existingTask!.time.split(':');
      if (parts.length >= 2) {
        bool isPm = widget.existingTask!.time.toLowerCase().contains('pm');
        int h = int.tryParse(parts[0]) ?? _minTime?.hour ?? 0;
        int m =
            int.tryParse(parts[1].replaceAll(RegExp(r'[^0-9]'), '')) ??
            _minTime?.minute ??
            0;
        if (isPm && h != 12) h += 12;
        if (!isPm && h == 12) h = 0;
        final now = DateTime.now();
        _selectedTime = DateTime(now.year, now.month, now.day, h, m);
      }
      _selectedDuration = Duration(
        minutes: widget.existingTask!.durationMinutes,
      );
      _isBreak = widget.existingTask!.isBreak;
      _hasSessionTimer = widget.existingTask!.hasSessionTimer;
      _selectedIconName = widget.existingTask!.iconName;
      _isKeyTask = widget.existingTask!.isKeyTask;
      _selectedWeekdays = List<int>.from(widget.existingTask!.weekdays);
      _selectedStateOfMind = widget.existingTask!.stateOfMind;
      _isUrgent = widget.existingTask!.isUrgent;
      _selectedPriority = widget.existingTask!.priority;
    }
  }

  List<Task> _getUniqueTemplates() {
    final custom = hiveService.readCustomTasks();
    final seen = <String>{};
    final templates = <Task>[];
    for (final t in custom) {
      final titleLower = t.title.trim().toLowerCase();
      if (titleLower.isNotEmpty && !seen.contains(titleLower)) {
        seen.add(titleLower);
        templates.add(t);
      }
    }

    final defaults = [
      Task(id: 'd1', sessionId: 'morning', title: 'Study', time: '', durationMinutes: 30, iconName: 'book', tip: 'Custom task'),
      Task(id: 'd2', sessionId: 'morning', title: 'Workout', time: '', durationMinutes: 45, iconName: 'workout', tip: 'Custom task'),
      Task(id: 'd3', sessionId: 'morning', title: 'Job Hunt', time: '', durationMinutes: 60, iconName: 'job', tip: 'Custom task'),
      Task(id: 'd4', sessionId: 'morning', title: 'Read Book', time: '', durationMinutes: 30, iconName: 'book', tip: 'Custom task'),
    ];
    for (final d in defaults) {
      final titleLower = d.title.trim().toLowerCase();
      if (!seen.contains(titleLower)) {
        seen.add(titleLower);
        templates.add(d);
      }
    }
    return templates;
  }

  void _updateTimeBounds() {
    final range = _selectedSession.timeRange
        .split(RegExp(r'\s*[-–—]\s*'))
        .map((s) => s.trim())
        .toList();
    if (range.length == 2) {
      _minTime = _parseTimeStrToDate(range[0]);
      _maxTime = _parseTimeStrToDate(range[1]);
      if (_minTime != null && _maxTime != null) {
        if (range[0].toLowerCase().contains('am') == false &&
            range[0].toLowerCase().contains('pm') == false) {
          final isPm = range[1].toLowerCase().contains('pm');
          if (isPm && _minTime!.hour < 12) {
            _minTime = _minTime!.add(const Duration(hours: 12));
          }
        }
        if (_maxTime!.isBefore(_minTime!)) {
          _maxTime = _maxTime!.add(const Duration(days: 1));
        }
        _selectedTime = _minTime!;
      }
    } else {
      _minTime = null;
      _maxTime = null;
    }
    if (_minTime != null) {
      _selectedTime = _minTime!;
    }
  }

  DateTime? _parseTimeStrToDate(String t) {
    t = t.toLowerCase();
    if (t.replaceAll(' ', '') == 'allday' || t.isEmpty) return null;
    bool isPm = t.contains('pm');
    t = t.replaceAll('am', '').replaceAll('pm', '').trim();
    final parts = t.split(':');
    if (parts.isEmpty) return null;
    int h = int.tryParse(parts[0]) ?? 0;
    int m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    if (isPm && h != 12) h += 12;
    if (!isPm && h == 12) h = 0;
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, h, m);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _saveTask() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final h = _selectedTime.hour.toString().padLeft(2, '0');
    final m = _selectedTime.minute.toString().padLeft(2, '0');
    final formattedTime = '$h:$m';

    if (widget.existingTask != null) {
      final updatedTask = widget.existingTask!.copyWith(
        title: title,
        time: formattedTime,
        durationMinutes: _selectedDuration.inMinutes,
        sessionId: _selectedSession.id,
        isBreak: _isBreak,
        hasSessionTimer: _hasSessionTimer,
        iconName: _selectedIconName,
        tip: 'key_task:$_isKeyTask|Custom task',
        weekdays: _selectedWeekdays,
        stateOfMind: _selectedStateOfMind,
        isUrgent: _isUrgent,
        priority: _selectedPriority,
      );
      ref
          .read(sessionsProvider.notifier)
          .editCustomTask(updatedTask, widget.existingTask!.sessionId);
    } else {
      final newTask = Task(
        id: const Uuid().v4(),
        sessionId: _selectedSession.id,
        title: title,
        time: formattedTime,
        durationMinutes: _selectedDuration.inMinutes,
        tip: 'key_task:$_isKeyTask|Custom task',
        isBreak: _isBreak,
        hasSessionTimer: _hasSessionTimer,
        iconName: _selectedIconName,
        weekdays: _selectedWeekdays,
        stateOfMind: _selectedStateOfMind,
        isUrgent: _isUrgent,
        priority: _selectedPriority,
        createdAt: DateTime.now(),
      );
      ref.read(sessionsProvider.notifier).addCustomTask(newTask);
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardPadding = MediaQuery.of(context).viewInsets.bottom;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardPadding),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: (screenHeight - keyboardPadding) * 0.92,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Fixed Header ───────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 8, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.existingTask != null ? 'Edit Task' : 'Add New Task',
                      style: AppTypography.screenTitle(color: AppColors.textPrimary),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: AppColors.textSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // ── Scrollable Fields ──────────────────────────────────
              Flexible(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPadding + 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    // 1. Active Days (Weekday Selector)
                    _WeekdaySelector(
                      selected: _selectedWeekdays,
                      onToggle: (day) {
                        setState(() {
                          if (_selectedWeekdays.contains(day)) {
                            _selectedWeekdays.remove(day);
                          } else {
                            _selectedWeekdays.add(day);
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 20),

                    // 2. Suggestions row
                    Builder(
                      builder: (context) {
                        final templates = _getUniqueTemplates();
                        if (templates.isEmpty) return const SizedBox.shrink();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Suggestions',
                              style: AppTypography.body(size: 13, weight: FontWeight.w600, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 38,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: templates.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 8),
                                itemBuilder: (context, i) {
                                  final t = templates[i];
                                  final iconData = _appIcons[t.iconName] ?? Icons.star_rounded;
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _titleController.text = t.title;
                                        if (_appIcons.containsKey(t.iconName)) {
                                          _selectedIconName = t.iconName;
                                        }
                                        _isBreak = t.isBreak;
                                        _hasSessionTimer = t.hasSessionTimer;
                                        _isKeyTask = t.isKeyTask;
                                        _selectedDuration = Duration(minutes: t.durationMinutes);
                                        _selectedStateOfMind = t.stateOfMind;
                                        _isUrgent = t.isUrgent;
                                        _selectedPriority = t.priority;
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: AppColors.cardSurface,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: AppColors.border),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(iconData, size: 16, color: AppColors.primary),
                                          const SizedBox(width: 6),
                                          Text(
                                            t.title,
                                            style: AppTypography.body(
                                              size: 13,
                                              weight: FontWeight.w600,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        );
                      },
                    ),

                    // 3. Task Title Input
                    TextField(
                      controller: _titleController,
                      style: AppTypography.body(size: 16, color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Task Name',
                        hintStyle: AppTypography.body(size: 16, color: AppColors.textMuted),
                        filled: true,
                        fillColor: AppColors.cardSurface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 4. Icon Picker
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _appIcons.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, i) {
                          final key = _appIcons.keys.elementAt(i);
                          final icon = _appIcons[key];
                          final isSelected = key == _selectedIconName;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedIconName = key),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primary : AppColors.cardSurface,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? AppColors.primary : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  icon,
                                  color: isSelected ? Colors.white : AppColors.textSecondary,
                                  size: 20,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 5. Session Selector
                    SizedBox(
                      height: 38,
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(_availableSessions.length, (i) {
                            final s = _availableSessions[i];
                            final isSelected = s.id == _selectedSession.id;
                            return Padding(
                              padding: EdgeInsets.only(
                                right: i < _availableSessions.length - 1 ? 8.0 : 0.0,
                              ),
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedSession = s;
                                    _updateTimeBounds();
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppColors.primary : Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isSelected ? AppColors.primary : AppColors.border,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      s.name,
                                      style: AppTypography.body(
                                        size: 12,
                                        weight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                        color: isSelected ? Colors.white : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 6. Toggles Row (Break, Timer, Key Task on a single line)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Break
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Break', style: AppTypography.body(size: 13, color: AppColors.textPrimary)),
                            const SizedBox(width: 4),
                            Transform.scale(
                              scale: 0.75,
                              child: CupertinoSwitch(
                                value: _isBreak,
                                activeTrackColor: AppColors.primary,
                                onChanged: (val) => setState(() {
                                  _isBreak = val;
                                  if (val) _isKeyTask = false;
                                }),
                              ),
                            ),
                          ],
                        ),
                        // Timer
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Timer', style: AppTypography.body(size: 13, color: AppColors.textPrimary)),
                            const SizedBox(width: 4),
                            Transform.scale(
                              scale: 0.75,
                              child: CupertinoSwitch(
                                value: _hasSessionTimer,
                                activeTrackColor: AppColors.primary,
                                onChanged: (val) => setState(() => _hasSessionTimer = val),
                              ),
                            ),
                          ],
                        ),
                        // Key Task
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Must Do', style: AppTypography.body(size: 13, color: AppColors.textPrimary)),
                            const SizedBox(width: 4),
                            Transform.scale(
                              scale: 0.75,
                              child: CupertinoSwitch(
                                value: _isKeyTask,
                                activeTrackColor: AppColors.primary,
                                onChanged: _isBreak ? null : (val) => setState(() => _isKeyTask = val),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // 7. Session time range label
                    Text(
                      _selectedSession.timeRange
                          .toUpperCase()
                          .replaceAll('AM', ' AM')
                          .replaceAll('PM', ' PM')
                          .replaceAll('  ', ' '),
                      style: AppTypography.mono(
                        size: 12,
                        weight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Time + Duration pickers (fixed height so they don't overflow)
                    SizedBox(
                      height: 180,
                      child: Row(
                        children: [
                          // Time picker
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Set a time',
                                  style: AppTypography.body(size: 14, color: AppColors.textSecondary),
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.cardSurface,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: CupertinoTheme(
                                      data: CupertinoTheme.of(context).copyWith(
                                        textTheme: CupertinoTextThemeData(
                                          dateTimePickerTextStyle: AppTypography.body(
                                            size: 18,
                                            weight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      child: CupertinoDatePicker(
                                        mode: CupertinoDatePickerMode.time,
                                        use24hFormat: true,
                                        initialDateTime: _selectedTime,
                                        minimumDate: _minTime,
                                        maximumDate: _maxTime,
                                        onDateTimeChanged: (val) => setState(() => _selectedTime = val),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Duration picker
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Duration',
                                  style: AppTypography.body(size: 14, color: AppColors.textSecondary),
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.cardSurface,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: CupertinoTheme(
                                      data: CupertinoTheme.of(context).copyWith(
                                        textTheme: CupertinoTextThemeData(
                                          dateTimePickerTextStyle: AppTypography.body(
                                            size: 18,
                                            weight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Expanded(
                                                child: CupertinoPicker(
                                                  itemExtent: 32,
                                                  scrollController: FixedExtentScrollController(
                                                    initialItem: _selectedDuration.inHours,
                                                  ),
                                                  selectionOverlay: const CupertinoPickerDefaultSelectionOverlay(
                                                    background: CupertinoColors.tertiarySystemFill,
                                                  ),
                                                  onSelectedItemChanged: (i) {
                                                    setState(() {
                                                      _selectedDuration = Duration(
                                                        hours: i,
                                                        minutes: _selectedDuration.inMinutes % 60,
                                                      );
                                                    });
                                                  },
                                                  children: List.generate(
                                                    24,
                                                    (i) => Center(
                                                      child: Padding(
                                                        padding: const EdgeInsets.only(right: 20),
                                                        child: Text(
                                                          '$i',
                                                          style: AppTypography.body(
                                                            size: 18,
                                                            weight: FontWeight.w600,
                                                            color: AppColors.textPrimary,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                child: CupertinoPicker(
                                                  itemExtent: 32,
                                                  scrollController: FixedExtentScrollController(
                                                    initialItem: (_selectedDuration.inMinutes % 60) ~/ 5,
                                                  ),
                                                  selectionOverlay: const CupertinoPickerDefaultSelectionOverlay(
                                                    background: CupertinoColors.tertiarySystemFill,
                                                  ),
                                                  onSelectedItemChanged: (i) {
                                                    setState(() {
                                                      _selectedDuration = Duration(
                                                        hours: _selectedDuration.inHours,
                                                        minutes: i * 5,
                                                      );
                                                    });
                                                  },
                                                  children: List.generate(
                                                    12,
                                                    (i) => Center(
                                                      child: Padding(
                                                        padding: const EdgeInsets.only(right: 20),
                                                        child: Text(
                                                          '${i * 5}',
                                                          style: AppTypography.body(
                                                            size: 18,
                                                            weight: FontWeight.w600,
                                                            color: AppColors.textPrimary,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          // H / M labels
                                          Positioned(
                                            left: 0,
                                            right: 0,
                                            child: IgnorePointer(
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Center(
                                                      child: Padding(
                                                        padding: const EdgeInsets.only(left: 24),
                                                        child: Text('H', style: AppTypography.body(size: 18, weight: FontWeight.w600)),
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Center(
                                                      child: Padding(
                                                        padding: const EdgeInsets.only(left: 30),
                                                        child: Text('M', style: AppTypography.body(size: 18, weight: FontWeight.w600)),
                                                      ),
                                                    ),
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
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // ── Fixed Save Button ──────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, bottomPadding + 16),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _saveTask,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    widget.existingTask != null ? 'Update Task' : 'Add Task',
                    style: AppTypography.body(
                      size: 16,
                      weight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}

// ── Weekday Selector ──────────────────────────────────────────────────────────
class _WeekdaySelector extends StatelessWidget {
  const _WeekdaySelector({required this.selected, required this.onToggle});

  final List<int> selected;
  final void Function(int day) onToggle;

  static const _labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _days = [1, 2, 3, 4, 5, 6, 7]; // ISO: Mon=1 … Sun=7

  @override
  Widget build(BuildContext context) {
    final isEmpty = selected.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Active Days',
              style: AppTypography.body(size: 13, weight: FontWeight.w600, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 8),
            if (isEmpty)
              Text(
                '(Every day)',
                style: AppTypography.body(size: 12, color: AppColors.textMuted),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(_days.length, (i) {
            final day = _days[i];
            final isOn = isEmpty || selected.contains(day);
            return GestureDetector(
              onTap: () => onToggle(day),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isOn ? AppColors.primary : AppColors.cardSurface,
                  border: Border.all(
                    color: isOn ? AppColors.primary : AppColors.border,
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    _labels[i],
                    style: AppTypography.body(
                      size: 13,
                      weight: FontWeight.w700,
                      color: isOn ? Colors.white : AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
