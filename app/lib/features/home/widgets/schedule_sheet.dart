import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../main.dart' show sharedPrefs;
import '../../../core/services/date_service.dart';

class ScheduledEvent {
  final String id;
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final int colorHex;

  ScheduledEvent({
    required this.id,
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.colorHex,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    'colorHex': colorHex,
  };

  factory ScheduledEvent.fromJson(Map<String, dynamic> json) => ScheduledEvent(
    id: json['id'] as String,
    title: json['title'] as String,
    startTime: DateTime.parse(json['startTime'] as String),
    endTime: DateTime.parse(json['endTime'] as String),
    colorHex: json['colorHex'] as int? ?? 0xFF3B82F6,
  );
}

class ScheduleSheet extends StatefulWidget {
  final DateTime date;

  const ScheduleSheet({super.key, required this.date});

  static Future<void> show(BuildContext context, DateTime date) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.9,
        child: ScheduleSheet(date: date),
      ),
    );
  }

  @override
  State<ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends State<ScheduleSheet> {
  static const double _hourHeight = 60.0;
  List<ScheduledEvent> _events = [];
  late String _storageKey;
  late DateTime _currentDate;

  @override
  void initState() {
    super.initState();
    _currentDate = widget.date;
    _loadEvents();
  }

  void _changeDate(DateTime newDate) {
    setState(() {
      _currentDate = newDate;
    });
    _loadEvents();
  }

  void _loadEvents() {
    _storageKey = 'schedule_${dateService.keyFor(_currentDate)}';
    final jsonStr = sharedPrefs.getString(_storageKey);
    if (jsonStr != null && jsonStr != '[]') {
      try {
        final List<dynamic> list = jsonDecode(jsonStr);
        setState(() {
          _events = list.map((e) => ScheduledEvent.fromJson(e)).toList();
        });
        return;
      } catch (_) {}
    }

    setState(() {
      _events = [];
    });

    // Migration: If no new events, check for old text-based event
    final oldKey = 'event_${dateService.keyFor(_currentDate)}';
    final oldVal = sharedPrefs.getString(oldKey);
    if (oldVal != null && oldVal.isNotEmpty) {
      final migratedEvent = ScheduledEvent(
        id: const Uuid().v4(),
        title: oldVal,
        startTime: DateTime(
          _currentDate.year,
          _currentDate.month,
          _currentDate.day,
          9,
          0,
        ),
        endTime: DateTime(
          _currentDate.year,
          _currentDate.month,
          _currentDate.day,
          10,
          0,
        ),
        colorHex: 0xFFEF4444, // Red for migrated events
      );
      setState(() {
        _events = [migratedEvent];
      });
      _saveEvents(); // Save in new format
      sharedPrefs.remove(oldKey); // Cleanup old format
    }
  }

  Future<void> _saveEvents() async {
    final list = _events.map((e) => e.toJson()).toList();
    await sharedPrefs.setString(_storageKey, jsonEncode(list));
  }

  void _addEventAt(int hour) {
    HapticFeedback.selectionClick();
    final start = DateTime(
      _currentDate.year,
      _currentDate.month,
      _currentDate.day,
      hour,
      0,
    );
    final end = start.add(const Duration(hours: 1));

    _showEditDialog(
      ScheduledEvent(
        id: const Uuid().v4(),
        title: '',
        startTime: start,
        endTime: end,
        colorHex: 0xFF3B82F6, // Default blue
      ),
      isNew: true,
    );
  }

  Future<void> _showEditDialog(
    ScheduledEvent event, {
    bool isNew = false,
  }) async {
    final ctrl = TextEditingController(text: event.title);
    TimeOfDay startT = TimeOfDay.fromDateTime(event.startTime);
    TimeOfDay endT = TimeOfDay.fromDateTime(event.endTime);
    final int colorHex = event.colorHex;

    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;

          return Padding(
            padding: EdgeInsets.only(
              bottom: bottomInset,
              left: 16,
              right: 16,
              top: 12,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isNew ? 'Add New Session' : 'Edit Session',
                        style: AppTypography.body(
                          size: 16,
                          weight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          if (ctrl.text.trim().isEmpty) return;
                          final newStart = DateTime(
                            event.startTime.year,
                            event.startTime.month,
                            event.startTime.day,
                            startT.hour,
                            startT.minute,
                          );
                          final newEnd = DateTime(
                            event.endTime.year,
                            event.endTime.month,
                            event.endTime.day,
                            endT.hour,
                            endT.minute,
                          );
                          final updated = ScheduledEvent(
                            id: event.id,
                            title: ctrl.text.trim(),
                            startTime: newStart,
                            endTime: newEnd,
                            colorHex: colorHex,
                          );
                          setState(() {
                            if (isNew) {
                              _events.add(updated);
                            } else {
                              final i = _events.indexWhere(
                                (e) => e.id == event.id,
                              );
                              if (i >= 0) _events[i] = updated;
                            }
                          });
                          _saveEvents();
                          Navigator.pop(ctx);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Save',
                            style: AppTypography.body(
                              size: 14,
                              weight: FontWeight.w700,
                              color: AppColors.background,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Title Input
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.cardSurface,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: ctrl,
                      autofocus: isNew,
                      style: AppTypography.body(
                        size: 14,
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: "What's the session?",
                        hintStyle: AppTypography.body(
                          size: 14,
                          color: AppColors.textMuted,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Times Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildTimeBox(
                          label: 'Start time',
                          time:
                              '${startT.hour.toString().padLeft(2, '0')}:${startT.minute.toString().padLeft(2, '0')}',
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: startT,
                              builder: (context, child) => MediaQuery(
                                data: MediaQuery.of(
                                  context,
                                ).copyWith(alwaysUse24HourFormat: true),
                                child: child!,
                              ),
                            );
                            if (picked != null) {
                              setDlgState(() => startT = picked);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 8,
                        height: 1,
                        color: AppColors.border,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildTimeBox(
                          label: 'End time',
                          time:
                              '${endT.hour.toString().padLeft(2, '0')}:${endT.minute.toString().padLeft(2, '0')}',
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: endT,
                              builder: (context, child) => MediaQuery(
                                data: MediaQuery.of(
                                  context,
                                ).copyWith(alwaysUse24HourFormat: true),
                                child: child!,
                              ),
                            );
                            if (picked != null) {
                              setDlgState(() => endT = picked);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  const SizedBox(height: 12),

                  // Notes
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.cardSurface,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      maxLines: 3,
                      style: AppTypography.body(
                        size: 14,
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: "Add notes...",
                        hintStyle: AppTypography.body(
                          size: 14,
                          color: AppColors.textMuted,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Delete button for editing
                  if (!isNew)
                    Center(
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            _events.removeWhere((e) => e.id == event.id);
                          });
                          _saveEvents();
                          Navigator.pop(ctx);
                        },
                        child: Text(
                          'Delete Session',
                          style: AppTypography.body(
                            size: 14,
                            color: Colors.redAccent,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimeBox({
    required String label,
    required String time,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.body(
                    size: 10,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  time,
                  style: AppTypography.body(
                    size: 14,
                    color: AppColors.textPrimary,
                    weight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            Icon(
              Icons.access_time_rounded,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeGrid() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Background lines
        Column(
          children: List.generate(24, (hour) {
            return SizedBox(
              height: _hourHeight,
              child: Stack(
                children: [
                  // Horizontal line
                  Positioned(
                    top: 10,
                    left: 64,
                    right: 0,
                    child: Container(
                      height: 1,
                      color: AppColors.border.withValues(alpha: 0.3),
                    ),
                  ),
                  // Time Text
                  Positioned(
                    top: 0,
                    left: 16,
                    child: Text(
                      '${hour.toString().padLeft(2, '0')}:00',
                      style: AppTypography.mono(
                        size: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  // Vertical dotted line connecting the times
                  if (hour < 23)
                    Positioned(
                      top: 20,
                      left: 32, // Centered roughly under time text
                      bottom: -10,
                      child: CustomPaint(
                        painter: _DottedLinePainter(),
                        size: const Size(1, double.infinity),
                      ),
                    ),
                  // Tap target
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _addEventAt(hour),
                      child: Container(),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),

        // Events
        ..._events.map((event) {
          final startMinutes =
              event.startTime.hour * 60 + event.startTime.minute;
          final endMinutes = event.endTime.hour * 60 + event.endTime.minute;
          final duration = (endMinutes - startMinutes).clamp(
            15,
            1440,
          ); // min 15 mins

          final topOffset = (startMinutes / 60) * _hourHeight;
          final height = (duration / 60) * _hourHeight;

          return Positioned(
            top: topOffset,
            left: 60, // past the time labels
            right: 16,
            height: height,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                _showEditDialog(event);
              },
              child: Container(
                margin: const EdgeInsets.only(top: 1, bottom: 1),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Color(event.colorHex).withValues(alpha: 0.15),
                  border: Border.all(
                    color: Color(event.colorHex).withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  event.title,
                  style: AppTypography.body(
                    size: 13,
                    weight: FontWeight.w600,
                    color: Color(event.colorHex),
                  ),
                  maxLines: height < 40 ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildWeekStrip() {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: 30, // 30 days ahead
        itemBuilder: (context, index) {
          final date = widget.date.add(Duration(days: index));
          final isSelected =
              date.year == _currentDate.year &&
              date.month == _currentDate.month &&
              date.day == _currentDate.day;

          return GestureDetector(
            onTap: () => _changeDate(date),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? Colors.black : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    days[date.weekday - 1],
                    style: AppTypography.body(
                      size: 11,
                      weight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? Colors.white70
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${date.day}',
                    style: AppTypography.body(
                      size: 15,
                      weight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayName = days[_currentDate.weekday - 1];

    return Stack(
      children: [
        Column(
          children: [
            // Top Drag Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dayName,
                        style: AppTypography.body(
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        '${_currentDate.day}',
                        style: AppTypography.screenTitle(
                          color: AppColors.textPrimary,
                        ).copyWith(fontSize: 32, height: 1.1),
                      ),
                    ],
                  ),
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surfaceRaised.withValues(alpha: 0.3),
                    ),
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close_rounded,
                        color: AppColors.textPrimary,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Week Strip
            _buildWeekStrip(),

            // Timeline
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 120),
                  child: _buildTimeGrid(),
                ),
              ),
            ),
          ],
        ),

        // FABs Overlay
        Positioned(
          right: 24,
          bottom: 24,
          child: GestureDetector(
            onTap: () {
              _addEventAt(DateTime.now().hour);
            },
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.add, size: 28, color: Colors.black),
            ),
          ),
        ),
      ],
    );
  }
}

class _DottedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.4)
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    double startY = 0;
    while (startY < size.height) {
      canvas.drawLine(Offset(0, startY), Offset(0, startY + 2), paint);
      startY += 6;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
