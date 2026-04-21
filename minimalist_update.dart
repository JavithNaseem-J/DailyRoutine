import 'dart:io';

void main() {
  final file = File('app/lib/features/home/home_screen.dart');
  var content = file.readAsStringSync();

  // 1. Replace GoalRing completely
  final goalRingStart = content.indexOf('class _GoalRing extends StatelessWidget {');
  final nextClassAfterGoalRing = content.indexOf('class _GoalBtn ', goalRingStart);
  
  if (goalRingStart != -1 && nextClassAfterGoalRing != -1) {
    final replacementGoalRing = '''class _GoalRing extends StatelessWidget {
  const _GoalRing({
    required this.icon,
    required this.label,
    required this.ringColor,
    required this.fraction,
    required this.valueText,
    required this.onIncrement,
    required this.onDecrement,
  });

  final IconData icon;
  final String label;
  final Color ringColor;
  final double fraction;
  final String valueText;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: ringColor, size: 14),
              const SizedBox(width: 5),
              Text(label,
                  style: AppTypography.body(
                      size: 12,
                      weight: FontWeight.w600,
                      color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 14),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: fraction.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOut,
            builder: (_, value, __) => SizedBox(
              width: 90,
              height: 90,
              child: CustomPaint(
                painter: _ArcPainter(
                  fraction: value,
                  ringColor: ringColor,
                  trackColor: AppColors.surfaceRaised,
                  strokeWidth: 9,
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: value >= 1.0
                        ? const Icon(Icons.check_circle_rounded, color: AppColors.complete, size: 32)
                        : Text(
                            valueText,
                            textAlign: TextAlign.center,
                            style: AppTypography.mono(
                                size: 12,
                                weight: FontWeight.w700,
                                color: AppColors.textPrimary),
                          ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _GoalBtn(icon: Icons.remove, onTap: onDecrement),
              const SizedBox(width: 22),
              _GoalBtn(
                  icon: Icons.add,
                  onTap: onIncrement,
                  filled: true,
                  color: ringColor),
            ],
          ),
        ],
      ),
    );
  }
}

''';
    content = content.replaceRange(goalRingStart, nextClassAfterGoalRing, replacementGoalRing);
  }

  // 2. Replace _ProgressCardState build method
  final progressCardBuildStart = content.indexOf('  @override\n  Widget build(BuildContext context) {', content.indexOf('class _ProgressCardState'));
  final progressCardBuildEnd = content.indexOf('class _WaterWalkRow', progressCardBuildStart);
  
  if (progressCardBuildStart != -1 && progressCardBuildEnd != -1) {
    final replacementProgressCard = '''  @override
  Widget build(BuildContext context) {
    final pct = widget.item.progress;
    final isComplete = pct >= 100;

    return GestureDetector(
      onLongPress: () => _showEditOptions(context),
      onPanUpdate: (d) {
        if (!_isEditing) {
          final p = (d.localPosition.dx / widget.width * 100).clamp(0.0, 100.0).round();
          widget.onProgressChanged(p);
        }
      },
      onTapDown: (d) {
        if (!_isEditing) {
          final p = (d.localPosition.dx / widget.width * 100).clamp(0.0, 100.0).round();
          widget.onProgressChanged(p);
        }
      },
      child: Container(
        width: widget.width,
        margin: const EdgeInsets.only(right: 14),
        // Drop shadow for the outer card
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // 1. SOLID WHITE BACKGROUND
              Container(
                color: Colors.white,
              ),

              // 2. SUBTLE GREY FILL FOR PROGRESS
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOutCubic,
                width: widget.width * (pct / 100).clamp(0.0, 1.0),
                decoration: const BoxDecoration(
                  color: Color(0xFFF3F4F6), // pale grey liquid fill
                ),
              ),

              // 3. THICK BLACK BORDER
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black, width: 2.5),
                ),
              ),

              // 4. FOREGROUND CONTENT
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row: Category Badge + Progress Text
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Task Name / Category Badge
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(widget.cardIcon, size: 16, color: Colors.black),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 80,
                              child: IgnorePointer(
                                ignoring: !_isEditing,
                                child: TextField(
                                  controller: _noteCtrl,
                                  readOnly: !_isEditing,
                                  onChanged: (v) => _debounced(() => widget.onNoteChanged(v)),
                                  style: AppTypography.body(
                                    size: 15,
                                    weight: FontWeight.w900,
                                    color: Colors.black, // Dark and bolder
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Task Name',
                                    hintStyle: AppTypography.body(
                                      size: 15,
                                      weight: FontWeight.w900,
                                      color: Colors.black45,
                                    ),
                                    border: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    errorBorder: InputBorder.none,
                                    disabledBorder: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        // Percentage Text
                        _isEditing
                          ? GestureDetector(
                              onTap: () => setState(() => _isEditing = false),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Colors.black,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check_rounded, size: 18, color: Colors.white),
                              ),
                            )
                          : Text(
                              isComplete ? 'DONE' : '\$pct%',
                              style: AppTypography.mono(
                                size: 28,
                                weight: FontWeight.w900,
                                color: Colors.black, // Darker
                              ),
                            ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Description
                    IgnorePointer(
                      ignoring: !_isEditing,
                      child: TextField(
                        controller: _nameCtrl,
                        readOnly: !_isEditing,
                        onChanged: (v) => _debounced(() => widget.onNameChanged(v)),
                        maxLines: 2,
                        style: AppTypography.body(
                          size: 17,
                          weight: FontWeight.w700,
                          color: Colors.black87, // Darker
                          height: 1.2,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Description',
                          hintStyle: AppTypography.body(
                            size: 17,
                            weight: FontWeight.w700,
                            color: Colors.black38,
                          ),
                          border: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    
                    const Spacer(),
                    
                    // Interactive Hint Text
                    if (!_isEditing)
                      Text(
                        isComplete ? 'Goal achieved!' : 'Drag across to adjust...',
                        style: AppTypography.label(
                          color: Colors.black54,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────
''';
    content = content.replaceRange(progressCardBuildStart, progressCardBuildEnd, replacementProgressCard);
  }

  file.writeAsStringSync(content);
  print('Changes injected to script!');
}
