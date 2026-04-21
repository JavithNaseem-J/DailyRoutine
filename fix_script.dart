import 'dart:io';

void main() {
  final file = File('app/lib/features/home/home_screen.dart');
  var content = file.readAsStringSync();
  final indexStart = content.indexOf('borderRadius: BorderRadius.circular(          IntrinsicHeight(');
  final indexEnd = content.indexOf('class _WeekStrip');
  
  if (indexStart != -1 && indexEnd != -1) {
    var replacement = '''borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Today's Progress",
                  style: AppTypography.body(
                      size: 13, weight: FontWeight.w500, color: AppColors.textPrimary)),
              Text('\$completionPct%',
                  style: AppTypography.mono(
                      size: 12,
                      weight: FontWeight.w600,
                      color: completionPct >= 80
                          ? AppColors.complete
                          : AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(builder: (_, constraints) {
            return Stack(children: [
              Container(
                height: 6,
                width: constraints.maxWidth,
                decoration: BoxDecoration(
                  color: AppColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOut,
                height: 6,
                width: constraints.maxWidth * (completionPct / 100),
                decoration: BoxDecoration(
                  color: AppColors.complete,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ]);
          }),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────
// Week Strip
// ──────────────────────────────────────────────────

''';
    content = content.replaceRange(indexStart, indexEnd, replacement);
    file.writeAsStringSync(content);
    print('Fixed gracefully!');
  } else {
    print('Pattern not found.');
  }
}
