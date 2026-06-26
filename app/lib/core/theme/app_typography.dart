import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// AppTypography — premium two-font system.
///
/// body()    → Urbanist     (headings, labels, body copy)   w100–w900
/// mono()    → Space Grotesk (numbers, stats, timers, badges) w300–w700
///              Uses tabular figures so digits don't shift width — safe for timers.
abstract final class AppTypography {
  static TextStyle body({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color? color,
    FontStyle style = FontStyle.normal,
    double? height,
    double? letterSpacing,
  }) =>
      GoogleFonts.urbanist(
        fontSize: size,
        fontWeight: weight,
        color: color,
        fontStyle: style,
        height: height,
        letterSpacing: letterSpacing,
      );

  /// Display / number style — Space Grotesk with tabular figures.
  static TextStyle mono({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? height,
  }) =>
      GoogleFonts.spaceGrotesk(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// Large screen title — "Good Morning!"
  static TextStyle screenTitle({Color? color}) =>
      body(size: 22, weight: FontWeight.w700, color: color);

  /// Section headers — "Today Do-To-List", "Weekly Progress"
  static TextStyle sectionTitle({Color? color}) =>
      body(size: 16, weight: FontWeight.w600, color: color);

  /// Card title / task title
  static TextStyle cardTitle({Color? color}) =>
      body(size: 14, weight: FontWeight.w500, color: color);

  /// Small label / muted text
  static TextStyle label({Color? color}) =>
      body(size: 12, weight: FontWeight.w400, color: color);

  /// Large ring percentage — "82%"
  static TextStyle ringPercent({Color? color}) =>
      mono(size: 28, weight: FontWeight.w700, color: color);

  /// Countdown timer — "01:23"
  static TextStyle timerDisplay({Color? color}) =>
      mono(size: 22, weight: FontWeight.w600, color: color);

  /// Time label on task card — "08:30 AM"
  static TextStyle timeLabel({Color? color}) =>
      mono(size: 11, weight: FontWeight.w400, color: color);

  /// Streak number inside ring
  static TextStyle streakNumber({Color? color}) =>
      mono(size: 22, weight: FontWeight.w700, color: color);
}
