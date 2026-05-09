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

  @override
  void initState() {
    super.initState();
    _storageKey = 'schedule_${dateService.keyFor(widget.date)}';
    _loadEvents();
  }

  void _loadEvents() {
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

    // Migration: If no new events, check for old text-based event
    final oldKey = 'event_${dateService.keyFor(widget.date)}';
    final oldVal = sharedPrefs.getString(oldKey);
    if (oldVal != null && oldVal.isNotEmpty) {
      final migratedEvent = ScheduledEvent(
        id: const Uuid().v4(),
        title: oldVal,
        startTime: DateTime(widget.date.year, widget.date.month, widget.date.day, 9, 0),
        endTime: DateTime(widget.date.year, widget.date.month, widget.date.day, 10, 0),
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
      widget.date.year,
      widget.date.month,
      widget.date.day,
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

  Future<void> _showEditDialog(ScheduledEvent event, {bool isNew = false}) async {
    final ctrl = TextEditingController(text: event.title);
    TimeOfDay startT = TimeOfDay.fromDateTime(event.startTime);
    TimeOfDay endT = TimeOfDay.fromDateTime(event.endTime);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          return AlertDialog(
            backgroundColor: AppColors.cardSurface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              isNew ? 'New Event' : 'Edit Event',
              style: AppTypography.body(size: 18, weight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: ctrl,
                  autofocus: isNew,
                  style: AppTypography.body(size: 15, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Event title',
                    hintStyle: AppTypography.body(size: 15, color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final picked = await showTimePicker(context: context, initialTime: startT);
                          if (picked != null) setDlgState(() => startT = picked);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            startT.format(context),
                            style: AppTypography.mono(size: 14, weight: FontWeight.w600, color: AppColors.primary),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.arrow_forward_rounded, color: AppColors.textMuted, size: 16),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final picked = await showTimePicker(context: context, initialTime: endT);
                          if (picked != null) setDlgState(() => endT = picked);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            endT.format(context),
                            style: AppTypography.mono(size: 14, weight: FontWeight.w600, color: AppColors.primary),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              if (!isNew)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _events.removeWhere((e) => e.id == event.id);
                    });
                    _saveEvents();
                    Navigator.pop(ctx);
                  },
                  child: Text('Delete', style: AppTypography.body(size: 14, color: Colors.redAccent)),
                ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: AppTypography.body(size: 14, color: AppColors.textSecondary)),
              ),
              TextButton(
                onPressed: () {
                  if (ctrl.text.trim().isEmpty) return;
                  
                  final newStart = DateTime(event.startTime.year, event.startTime.month, event.startTime.day, startT.hour, startT.minute);
                  final newEnd = DateTime(event.endTime.year, event.endTime.month, event.endTime.day, endT.hour, endT.minute);
                  
                  final updated = ScheduledEvent(
                    id: event.id,
                    title: ctrl.text.trim(),
                    startTime: newStart,
                    endTime: newEnd,
                    colorHex: event.colorHex,
                  );

                  setState(() {
                    if (isNew) {
                      _events.add(updated);
                    } else {
                      final i = _events.indexWhere((e) => e.id == event.id);
                      if (i >= 0) _events[i] = updated;
                    }
                  });
                  _saveEvents();
                  Navigator.pop(ctx);
                },
                child: Text('Save', style: AppTypography.body(size: 14, weight: FontWeight.w700, color: AppColors.primary)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTimeGrid() {
    return Stack(
      children: [
        // Background lines
        Column(
          children: List.generate(24, (hour) {
            return Container(
              height: _hourHeight,
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: AppColors.textMuted.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 16, right: 12, top: 4),
                    child: Text(
                      '${hour.toString().padLeft(2, '0')}:00',
                      style: AppTypography.mono(
                        size: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
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
          final startMinutes = event.startTime.hour * 60 + event.startTime.minute;
          final endMinutes = event.endTime.hour * 60 + event.endTime.minute;
          final duration = (endMinutes - startMinutes).clamp(15, 1440); // min 15 mins

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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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

  @override
  Widget build(BuildContext context) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayName = days[widget.date.weekday - 1];

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Row(
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
                    '${widget.date.day}',
                    style: AppTypography.screenTitle(
                      color: AppColors.textPrimary,
                    ).copyWith(fontSize: 28),
                  ),
                ],
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close_rounded, color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
        
        // Timeline
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: _buildTimeGrid(),
            ),
          ),
        ),
      ],
    );
  }
}
