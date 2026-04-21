import 'dart:io';

void main() {
  final file = File('app/lib/features/home/home_screen.dart');
  var content = file.readAsStringSync();
  
  // 1. Rename the long-press menu options:
  content = content.replaceFirst(
    "Text('Edit project details', style: AppTypography.body(size: 16))",
    "Text('Edit', style: AppTypography.body(size: 16))",
  );
  content = content.replaceFirst(
    "Text('Close Project (Delete)', style: AppTypography.body(size: 16, color: AppColors.moodLow))",
    "Text('Delete', style: AppTypography.body(size: 16, color: AppColors.moodLow))",
  );
  
  // 2. Change hints
  content = content.replaceFirst("hintText: 'Category...'", "hintText: 'Task Name...'");
  content = content.replaceFirst("hintText: 'Task name...'", "hintText: 'Description...'");
  
  // 3. Make InProgress card only editable on Edit
  // Find _ProgressCardState
  final stateStart = content.indexOf('class _ProgressCardState extends State<_ProgressCard> {');
  final buildStart = content.indexOf('Widget build(BuildContext context) {', stateStart);
  
  if (stateStart != -1 && buildStart != -1) {
    // Inject _isEditing
    var newVars = '''
  late final TextEditingController _nameCtrl;
  late final TextEditingController _noteCtrl;
  Timer? _debounce;
  bool _isEditing = false;
''';
    content = content.replaceFirst('''
  late final TextEditingController _nameCtrl;
  late final TextEditingController _noteCtrl;
  Timer? _debounce;
''', newVars);

    // Update Edit onTap
    content = content.replaceFirst('''
                  onTap: () {
                    Navigator.pop(ctx);
                  },
''', '''
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _isEditing = true);
                  },
''');

    // Substitute TextField and icons with readOnly logic
    // We can just use String replacements.
    content = content.replaceFirst('''
                  child: TextField(
                    controller: _noteCtrl,
''', '''
                  child: TextField(
                    controller: _noteCtrl,
                    readOnly: !_isEditing,
''');

    content = content.replaceFirst('''
            child: TextField(
              controller: _nameCtrl,
''', '''
            child: TextField(
              controller: _nameCtrl,
              readOnly: !_isEditing,
''');

    content = content.replaceFirst('''
              const SizedBox(width: 8),
              Icon(widget.cardIcon, color: widget.accent, size: 20),
''', '''
              const SizedBox(width: 8),
              _isEditing
                  ? GestureDetector(
                      onTap: () => setState(() => _isEditing = false),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(shape: BoxShape.circle, color: widget.accent),
                        child: const Icon(Icons.check, size: 12, color: AppColors.background),
                      ),
                    )
                  : Icon(widget.cardIcon, color: widget.accent, size: 20),
''');

    // Disable progress slider when NOT editing?
    // User says "then only i should can edit", meaning everything or just text?
    // Let's disable progress adjustment when NOT editing too, makes it simpler. Or maybe the user wants to adjust progress anytime?
    // Usually progress is interactive. I'll leave progress interactive.

  }
  
  // 4. Create Project Bottom Sheet
  // To make creation "modern cool", we'll intercept the `onAdd` calls.
  // Wait, in `_HomeScreenState`, `_addProgressItem` does:
  // final newItem = ProgressItem(..., name: '', note: '');
  // Let's modify `_HomeScreenState` to pop a bottom sheet first!
  final addProgress = content.indexOf('void _addProgressItem() {');
  if (addProgress != -1) {
    final oldMethod = '''
  void _addProgressItem() {
    if (_progressItems.length >= 3) return;
    final newItem = ProgressItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: '',
      note: '',
      progress: 0,
    );
    setState(() => _progressItems.add(newItem));
    _saveProgressItems();
  }
''';
    final newMethod = '''
  void _addProgressItem() {
    if (_progressItems.length >= 3) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        String note = '';
        String name = '';
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 24, right: 24, top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Start New Project', style: AppTypography.body(size: 20, weight: FontWeight.w800)),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: TextField(
                  autofocus: true,
                  style: AppTypography.body(size: 15, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Task Name (e.g. Health)',
                    hintStyle: AppTypography.body(size: 15, color: AppColors.textMuted),
                    border: InputBorder.none,
                  ),
                  onChanged: (v) => note = v,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: TextField(
                  style: AppTypography.body(size: 15, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Description (e.g. Morning Workout)',
                    hintStyle: AppTypography.body(size: 15, color: AppColors.textMuted),
                    border: InputBorder.none,
                  ),
                  onChanged: (v) => name = v,
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () {
                  if (note.trim().isEmpty && name.trim().isEmpty) {
                    Navigator.pop(ctx);
                    return;
                  }
                  final newItem = ProgressItem(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: name,
                    note: note,
                    progress: 0,
                  );
                  Navigator.pop(ctx);
                  setState(() => _progressItems.add(newItem));
                  _saveProgressItems();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: Text('Create Project', style: AppTypography.body(size: 16, weight: FontWeight.w700, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }
''';
    content = content.replaceFirst(oldMethod, newMethod);
  }

  file.writeAsStringSync(content);
  print('Changes built and injected!');
}
