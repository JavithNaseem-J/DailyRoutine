import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/session_data.dart';
import '../../core/models/session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import 'providers/sessions_provider.dart';

class AddTaskSheet extends ConsumerStatefulWidget {
  final Session defaultSession;
  final Task? existingTask;

  const AddTaskSheet({
    super.key,
    required this.defaultSession,
    this.existingTask,
  });

  @override
  ConsumerState<AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends ConsumerState<AddTaskSheet> {
  late Session _selectedSession;
  final _titleController = TextEditingController();

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
    _availableSessions = SessionData.sessionsForToday(
      isFriday: DateTime.now().weekday == DateTime.friday,
      isSunday: DateTime.now().weekday == DateTime.sunday,
    );
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
    }
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
        // If maxTime wrapped past midnight or is am/pm logic
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

    final isPm = _selectedTime.hour >= 12;
    final h = _selectedTime.hour == 0 
        ? 12 
        : _selectedTime.hour > 12 
            ? _selectedTime.hour - 12 
            : _selectedTime.hour;
    final m = _selectedTime.minute.toString().padLeft(2, '0');
    final formattedTime = '$h:$m${isPm ? "pm" : "am"}';

    if (widget.existingTask != null) {
      final updatedTask = Task(
        id: widget.existingTask!.id,
        sessionId: _selectedSession.id,
        title: title,
        time: formattedTime,
        durationMinutes: _selectedDuration.inMinutes,
        tip: widget.existingTask!.tip,
      );
      ref
          .read(sessionsProvider.notifier)
          .editCustomTask(updatedTask, widget.existingTask!.sessionId);
    } else {
      final newTask = Task(
        id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
        sessionId: _selectedSession.id,
        title: title,
        time: formattedTime,
        durationMinutes: _selectedDuration.inMinutes,
        tip: 'Custom task',
      );
      ref.read(sessionsProvider.notifier).addCustomTask(newTask);
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: EdgeInsets.only(
        top: 24,
        left: 20,
        right: 20,
        bottom:
            MediaQuery.of(context).viewInsets.bottom + 24, // Keyboard padding
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
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
          const SizedBox(height: 16),

          // Session Selector
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _availableSessions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final s = _availableSessions[i];
                final isSelected = s.id == _selectedSession.id;
                return GestureDetector(
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
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.border,
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        s.name,
                        style: AppTypography.body(
                          size: 12,
                          weight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // Task Title Input
          TextField(
            controller: _titleController,
            style: AppTypography.body(size: 16, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Task Name',
              hintStyle: AppTypography.body(
                size: 16,
                color: AppColors.textMuted,
              ),
              filled: true,
              fillColor: AppColors.cardSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _selectedSession.timeRange
                .toUpperCase()
                .replaceAll('AM', ' AM')
                .replaceAll('PM', ' PM')
                .replaceAll('  ', ' ')
                .replaceAll('â€“', '-'),
            style: AppTypography.mono(
              size: 12,
              weight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),

          // Row for Time and Duration pickers
          Expanded(
            child: Row(
              children: [
                // Set a Time
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Set a time',
                        style: AppTypography.body(
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
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
                              initialDateTime: _selectedTime,
                              minimumDate: _minTime,
                              maximumDate: _maxTime,
                              onDateTimeChanged: (val) =>
                                  setState(() => _selectedTime = val),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Duration
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Duration',
                        style: AppTypography.body(
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
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
                                                minutes: _selectedDuration.inMinutes % 60);
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
                                                    ))),
                                      ),
                                    ),
                                    Expanded(
                                      child: CupertinoPicker(
                                        itemExtent: 32,
                                        scrollController: FixedExtentScrollController(
                                          initialItem:
                                              (_selectedDuration.inMinutes % 60) ~/ 5,
                                        ),
                                        selectionOverlay: const CupertinoPickerDefaultSelectionOverlay(
                                          background: CupertinoColors.tertiarySystemFill,
                                        ),
                                        onSelectedItemChanged: (i) {
                                          setState(() {
                                            _selectedDuration = Duration(
                                                hours: _selectedDuration.inHours,
                                                minutes: i * 5);
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
                                                    ))),
                                      ),
                                    ),
                                  ],
                                ),
                                // Static Labels
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
          const SizedBox(height: 24),

          // Save Button
          SizedBox(
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
        ],
      ),
    );
  }
}







