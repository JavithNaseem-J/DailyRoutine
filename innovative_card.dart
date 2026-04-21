import 'dart:io';

void main() {
  final file = File('app/lib/features/home/home_screen.dart');
  var content = file.readAsStringSync();

  final startCard = content.indexOf('class _ProgressCard extends StatefulWidget {');
  final endCard = content.indexOf('class _WaterWalkRow extends StatelessWidget {');

  if (startCard == -1 || endCard == -1) {
    print('Could not find card bounds.');
    return;
  }

  final replacement = '''class _ProgressCard extends StatefulWidget {
  const _ProgressCard({
    super.key,
    required this.item,
    required this.index,
    required this.width,
    required this.bgColor,
    required this.accent,
    required this.cardIcon,
    required this.onNameChanged,
    required this.onProgressChanged,
    required this.onNoteChanged,
    required this.onDelete,
  });

  final ProgressItem item;
  final int index;
  final double width;
  final Color bgColor;
  final Color accent;
  final IconData cardIcon;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<int> onProgressChanged;
  final ValueChanged<String> onNoteChanged;
  final VoidCallback onDelete;

  @override
  State<_ProgressCard> createState() => _ProgressCardState();
}

class _ProgressCardState extends State<_ProgressCard> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _noteCtrl;
  Timer? _debounce;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.item.name);
    _noteCtrl = TextEditingController(text: widget.item.note);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _noteCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _debounced(VoidCallback fn) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), fn);
  }

  void _showEditOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_rounded, color: AppColors.textPrimary),
              title: Text('Edit', style: AppTypography.body(size: 16)),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _isEditing = true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AppColors.moodLow),
              title: Text('Delete', style: AppTypography.body(size: 16, color: AppColors.moodLow)),
              onTap: () {
                Navigator.pop(ctx);
                widget.onDelete();
              },
            ),
            ListTile(
              leading: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
              title: Text('Cancel', style: AppTypography.body(size: 16)),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  @override
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
    );
  }
}

// ──────────────────────────────────────────────────
// Water + Walk Row  (no header)
// ──────────────────────────────────────────────────

''';

  content = content.replaceRange(startCard, endCard, replacement);
  file.writeAsStringSync(content);
  print('Innovative redesign applied!');
}
