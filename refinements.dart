import 'dart:io';

void main() {
  final file = File('app/lib/features/home/home_screen.dart');
  var content = file.readAsStringSync();

  // 1. Fix _GoalRing Tick Color (AppColors.complete -> ringColor)
  final goalRingTickStr = 'const Icon(Icons.check_circle_rounded, color: AppColors.complete, size: 32)';
  content = content.replaceFirst(goalRingTickStr, 'Icon(Icons.check_circle_rounded, color: ringColor, size: 32)');

  // 2. Fix In Progress TextFields (Remove Icons, Expand, White Fill, Transparent Hover)
  final pStateBuild = content.indexOf('class _ProgressCardState extends State<_ProgressCard> {');
  final pStateBuildStart = content.indexOf('  @override\n  Widget build(BuildContext context) {', pStateBuild);
  final pStateBuildEnd = content.indexOf('class _WaterWalkRow', pStateBuildStart);

  if (pStateBuildStart != -1 && pStateBuildEnd != -1) {
    final newBuild = '''  @override
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
              Container(color: Colors.white),

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
                    // Header Row: Task Name + Progress Text
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Expanded Task Name (No Icon)
                        Expanded(
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
                                fillColor: Colors.white,
                                filled: true,
                                hoverColor: Colors.transparent,
                                focusColor: Colors.transparent,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2), // Small padding to look natural
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        
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
                          fillColor: Colors.white,
                          filled: true,
                          hoverColor: Colors.transparent,
                          focusColor: Colors.transparent,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                        ),
                      ),
                    ),
                    
                    const Spacer(),
                    
                    // Interactive Hint Text
                    if (!_isEditing)
                      Container(
                        color: Colors.white, // Solid white background behind hint
                        padding: const EdgeInsets.only(right: 8, top: 2),
                        child: Text(
                          isComplete ? 'Goal achieved!' : 'Drag across to adjust...',
                          style: AppTypography.label(
                            color: Colors.black54,
                          ),
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
    content = content.replaceRange(pStateBuildStart, pStateBuildEnd, newBuild);
  }

  // 3. Fix Task Board Add Task TextField colour change
  final taskBoardAdd = content.indexOf('child: TextField(', content.indexOf('class _TaskBoard'));
  final taskBoardAddEnd = content.indexOf('),', content.indexOf('decoration: InputDecoration(', taskBoardAdd));
  
  if (taskBoardAdd != -1 && taskBoardAddEnd != -1) {
    // Just replace the decoration part
    final decorationStart = content.indexOf('decoration: InputDecoration(', taskBoardAdd);
    final replacementDecoration = '''decoration: InputDecoration(
                    hintText: atLimit ? 'Max 5 tasks' : 'Add Task',
                    hintStyle: AppTypography.body(
                        size: 14, color: AppColors.textMuted),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    fillColor: Colors.transparent,
                    filled: true,
                    hoverColor: Colors.transparent,
                    focusColor: Colors.transparent,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 14)''';
    content = content.replaceRange(decorationStart, taskBoardAddEnd, replacementDecoration);
  }

  file.writeAsStringSync(content);
  print('Changes injected!');
}
