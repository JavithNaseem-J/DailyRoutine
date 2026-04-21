import 'dart:io';

void main() {
  final file = File('app/lib/features/home/home_screen.dart');
  var content = file.readAsStringSync();
  final indexStart = content.indexOf('Row(\n            crossAxisAlignment: CrossAxisAlignment.start,\n            children: [\n              // LEFT');
  final indexEnd = content.indexOf('          const SizedBox(height: 14);\n\n          // ── BOTTOM');
  
  if (indexStart != -1 && indexEnd != -1) {
    var replacement = '''IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // LEFT - top-aligned icon, label, name
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.mosque_outlined,
                                color: Colors.white54, size: 14),
                            const SizedBox(width: 5),
                            Text('Next Prayer',
                                style: AppTypography.label(color: Colors.white54)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(prayer.name,
                            style: AppTypography.body(
                                size: 24,
                                weight: FontWeight.w800,
                                color: Colors.white)),
                      ],
                    ),
                    Builder(builder: (context) {
                      final now = DateTime.now();
                      final remaining = now.isBefore(prayer.adhaan)
                          ? prayer.adhaan.difference(now)
                          : prayer.prayerStart.difference(now);
                      if (remaining.isNegative) return const SizedBox.shrink();
                      final hours = remaining.inHours;
                      final mins = remaining.inMinutes.remainder(60);
                      final rStr = hours > 0 ? '\${hours}h \${mins}m left' : '\${mins}m left';
                      return Row(
                        children: [
                          const Icon(Icons.timer_outlined, color: Colors.white54, size: 12),
                          const SizedBox(width: 4),
                          Text(rStr, style: AppTypography.mono(size: 11, color: Colors.white54)),
                        ],
                      );
                    }),
                  ],
                ),
                const Spacer(),
                // RIGHT - adhaan + prayer start
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.volume_up_rounded,
                            size: 10, color: Colors.white38),
                        const SizedBox(width: 4),
                        Text('Adhaan',
                            style: AppTypography.label(color: Colors.white38)),
                      ],
                    ),
                    Text(_fmt(prayer.adhaan),
                        style: AppTypography.mono(
                            size: 15,
                            weight: FontWeight.w700,
                            color: Colors.white)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.accessibility_new_rounded,
                            size: 10, color: AppColors.complete),
                        const SizedBox(width: 4),
                        Text('Prayer',
                            style: AppTypography.label(color: AppColors.complete)),
                      ],
                    ),
                    Text(_fmt(prayer.prayerStart),
                        style: AppTypography.mono(
                            size: 15,
                            weight: FontWeight.w700,
                            color: AppColors.complete)),
                  ],
                ),
              ],
            ),
          ),
''';
    content = content.replaceRange(indexStart, indexEnd, replacement);
    file.writeAsStringSync(content);
    print('Fixed gracefully!');
  } else {
    print('Pattern not found.');
    print('Found start: \$indexStart');
    print('Found end: \$indexEnd');
  }
}
