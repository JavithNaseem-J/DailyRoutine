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

  // Find the exact end of _ProgressCardState by tracking backwards from endCard
  // But wait, the space between is just comments. We can just replace up to endCard.

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

  @override
  Widget build(BuildContext context) {
    final pct = widget.item.progress;
    final isComplete = pct >= 100;

    return GestureDetector(
      onLongPress: () {
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
      },
      child: Container(
        width: widget.width,
        margin: const EdgeInsets.only(right: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: widget.bgColor, // Use the provided rich dark backgrounds
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: widget.accent.withValues(alpha: 0.1), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 15,
              offset: const Offset(0, 6),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TOP ROW: Task Name Pill + Percent + Edit Done Check
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: widget.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(widget.cardIcon, size: 14, color: widget.accent),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 80,
                              child: TextField(
                                controller: _noteCtrl,
                                readOnly: !_isEditing,
                                onChanged: (v) => _debounced(() => widget.onNoteChanged(v)),
                                style: AppTypography.body(
                                  size: 12,
                                  weight: FontWeight.w800,
                                  color: widget.accent,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Task Name',
                                  hintStyle: AppTypography.body(
                                    size: 12,
                                    weight: FontWeight.w800,
                                    color: widget.accent.withValues(alpha: 0.5),
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                _isEditing
                    ? GestureDetector(
                        onTap: () => setState(() => _isEditing = false),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: widget.accent,
                          ),
                          child: const Icon(Icons.check_rounded, size: 16, color: AppColors.background),
                        ),
                      )
                    : Text(
                        isComplete ? 'DONE' : '\$pct%',
                        style: AppTypography.mono(
                          size: 16,
                          weight: FontWeight.w900,
                          color: isComplete ? widget.accent : Colors.white,
                        ),
                      ),
              ],
            ),

            const Spacer(),

            // MIDDLE: Description Text
            TextField(
              controller: _nameCtrl,
              readOnly: !_isEditing,
              onChanged: (v) => _debounced(() => widget.onNameChanged(v)),
              maxLines: 2,
              style: AppTypography.body(
                size: 18,
                weight: FontWeight.w800,
                color: Colors.white,
                height: 1.2,
              ),
              decoration: InputDecoration(
                hintText: 'Description',
                hintStyle: AppTypography.body(
                  size: 18,
                  weight: FontWeight.w800,
                  color: Colors.white38,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),

            const SizedBox(height: 18),

            // BOTTOM: Thick Interactive Progress Bar
            LayoutBuilder(builder: (ctx, constraints) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (d) {
                  final p = (d.localPosition.dx / constraints.maxWidth * 100)
                      .clamp(0.0, 100.0)
                      .round();
                  widget.onProgressChanged(p);
                },
                onTapDown: (d) {
                  final p = (d.localPosition.dx / constraints.maxWidth * 100)
                      .clamp(0.0, 100.0)
                      .round();
                  widget.onProgressChanged(p);
                },
                child: Container(
                  height: 12,
                  width: constraints.maxWidth,
                  decoration: BoxDecoration(
                    color: Colors.black26, // Deep inset track color
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.border.withValues(alpha: 0.1)),
                  ),
                  child: Stack(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        width: constraints.maxWidth * (pct / 100),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              widget.accent.withValues(alpha: 0.5),
                              widget.accent,
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: widget.accent.withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
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
  print('In-Progress card re-designed!');
}
