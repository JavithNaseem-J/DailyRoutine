import 'dart:io';

void main() {
  final file = File('app/lib/features/home/home_screen.dart');
  var content = file.readAsStringSync();
  
  // 1. Change fire icon
  content = content.replaceFirst(
    'const Icon(Icons.whatshot_rounded,\n                color: AppColors.textPrimary, size: 22),',
    'const Icon(Icons.local_fire_department_rounded,\n                color: AppColors.textPrimary, size: 22),',
  );
  content = content.replaceFirst(
    'const Icon(Icons.whatshot_rounded, color: AppColors.textPrimary, size: 22),',
    'const Icon(Icons.local_fire_department_rounded, color: AppColors.textPrimary, size: 22),',
  );
  
  // 2. allDone condition
  content = content.replaceFirst(
    'final allDone = tasks.isNotEmpty && tasks.every((t) => t.done);',
    'final allDone = tasks.length >= 5 && tasks.every((t) => t.done);',
  );
  
  // Also check if there's any other "All tasks done!" text formatting issue:
  // "i there is a issue in all tasks done! only i sould be in english" maybe he meant "All tasks done!" is fine now.

  file.writeAsStringSync(content);
  print('Minor tweaks applied!');
}
