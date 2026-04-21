import 'dart:io';

void main() {
  final file = File('app/lib/features/home/home_screen.dart');
  var content = file.readAsStringSync();

  // 1. Fix _QuoteCard alignment
  content = content.replaceFirst(
    '''
          Text(text,
              style: AppTypography.body(
                size: 13,
                style: FontStyle.italic,
                color: AppColors.textSecondary,
                height: 1.5,
              )),
''',
    '''
          Text(text,
              textAlign: TextAlign.justify,
              style: AppTypography.body(
                size: 13,
                style: FontStyle.italic,
                color: AppColors.textSecondary,
                height: 1.5,
              )),
'''
  );

  // 2. Fix TaskCard swiping gap
  // First, find the `Dismissible` inside _TaskCard.
  final taskCardStart = content.indexOf('class _TaskCard extends StatelessWidget {');
  final dismissibleStart = content.indexOf('child: Dismissible(', taskCardStart);
  
  if (dismissibleStart != -1) {
    // Replace `child: Dismissible(` with `child: ClipRRect(borderRadius: BorderRadius.circular(14), child: Dismissible(`
    content = content.replaceRange(
      dismissibleStart, dismissibleStart + 'child: Dismissible('.length,
      'child: ClipRRect(borderRadius: BorderRadius.circular(14), child: Dismissible('
    );
    
    // We added ClipRRect, so now we need an extra `)` at the end of _TaskCard build method.
    // The build method return ends at `;`
    // Let's find the end of `child: Dismissible(` structure.
    final paddingStart = content.lastIndexOf('return Padding(', dismissibleStart);
    final endOfPadding = content.indexOf(';\n  }\n}', paddingStart);
    if (endOfPadding != -1) {
      content = content.replaceRange(endOfPadding, endOfPadding + 1, ');');
    }
    
    // Remove border radius from the background containers in Dismissible
    content = content.replaceFirst('borderRadius: BorderRadius.circular(14),\n          ),\n          child: const Icon(Icons.check_circle_rounded,', '),\n          child: const Icon(Icons.check_circle_rounded,', taskCardStart);
    content = content.replaceFirst('borderRadius: BorderRadius.circular(14),\n          ),\n          child: const Icon(Icons.delete_sweep_rounded,', '),\n          child: const Icon(Icons.delete_sweep_rounded,', taskCardStart);
  }

  // 3. Fix ProgressCard ClipRRect and TextFields
  // Find _ProgressCardState build
  final pStateStart = content.indexOf('class _ProgressCardState extends State<_ProgressCard> {');
  final stackStart = content.indexOf('child: Stack(', pStateStart);
  if (stackStart != -1) {
    content = content.replaceRange(stackStart, stackStart + 'child: Stack('.length, 'child: ClipRRect(borderRadius: BorderRadius.circular(28), child: Stack(');
    // Again, find end of the Stack
    // The container wrapping the stack just ends with )
    final containerStart = content.lastIndexOf('child: Container(', stackStart);
    // Find where the Stack ends.
    // Since we wrapped `Stack` in `ClipRRect`, we need to find closing `)`
    // The simplest way is to manually insert the closing `)` after the `Stack(children: [...])`.
    // Actually, I can just replace the whole `_ProgressCardState` build method to be safe.
  }

  // Let's do a much safer replacement for _ProgressCardState build:
  final progressCardBuildStart = content.indexOf('  @override\n  Widget build(BuildContext context) {', pStateStart);
  final progressCardBuildEnd = content.indexOf('class _WaterWalkRow ', progressCardBuildStart);
  
  if (progressCardBuildStart != -1 && progressCardBuildEnd != -1) {
    final replacement = '''  @override
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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            children: [
              // 1. BASE BACKGROUND
              Container(
                decoration: BoxDecoration(
                  color: widget.bgColor,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))
                  ],
                ),
              ),

              // 2. LIQUID PROGRESS FILL
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOutCubic,
                width: widget.width * (pct / 100).clamp(0.0, 1.0),
                decoration: BoxDecoration(
                  color: widget.accent.withValues(alpha: 0.25), // Transparent glow
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: pct > 0 ? widget.accent.withValues(alpha: 0.5) : Colors.transparent, 
                    width: 1
                  ),
                ),
              ),

              // 3. EDIT OVERLAY BORDER (When editing)
              if (_isEditing)
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: AppColors.textPrimary, width: 2),
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
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black45, // Contrast backing
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(widget.cardIcon, size: 14, color: widget.accent),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 60,
                                child: IgnorePointer(
                                  ignoring: !_isEditing,
                                  child: TextField(
                                    controller: _noteCtrl,
                                    readOnly: !_isEditing,
                                    onChanged: (v) => _debounced(() => widget.onNoteChanged(v)),
                                    style: AppTypography.body(
                                      size: 12,
                                      weight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Task Name',
                                      hintStyle: AppTypography.body(
                                        size: 12,
                                        weight: FontWeight.w700,
                                        color: Colors.white54,
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
                        ),
                        
                        // Percentage Text
                        _isEditing
                          ? GestureDetector(
                              onTap: () => setState(() => _isEditing = false),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: widget.accent,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check_rounded, size: 18, color: Colors.white),
                              ),
                            )
                          : Text(
                              isComplete ? 'DONE' : '\$pct%',
                              style: AppTypography.mono(
                                size: 26,
                                weight: FontWeight.w900,
                                color: isComplete ? widget.accent : Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                      ],
                    ),
                    
                    const Spacer(),
                    
                    // Description
                    IgnorePointer(
                      ignoring: !_isEditing,
                      child: TextField(
                        controller: _nameCtrl,
                        readOnly: !_isEditing,
                        onChanged: (v) => _debounced(() => widget.onNameChanged(v)),
                        maxLines: 2,
                        style: AppTypography.body(
                          size: 22,
                          weight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.1,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Description',
                          hintStyle: AppTypography.body(
                            size: 22,
                            weight: FontWeight.w800,
                            color: Colors.white24,
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
                    
                    const SizedBox(height: 6),
                    
                    // Interactive Hint Text
                    if (!_isEditing)
                      Text(
                        isComplete ? 'Goal achieved!' : 'Drag across to adjust...',
                        style: AppTypography.label(
                          color: isComplete ? widget.accent : Colors.white38,
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
    content = content.replaceRange(progressCardBuildStart, progressCardBuildEnd, replacement);
  }

  file.writeAsStringSync(content);
  print('All feedback applied!');
}
