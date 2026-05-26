import 'package:flutter/material.dart';

/// AppColors — all colour tokens derived from the reference UI.
///
/// Palette: light-grey page background, WHITE cards with subtle shadow,
/// black primary, green progress, dark bottom nav.
abstract final class AppColors {
  // ── Page & surface ────────────────────────────────────────────────
  static Color background    = const Color(0xFFF6F7F9); // light grey page
  static Color cardSurface   = const Color(0xFFFFFFFF); // white cards
  static Color surfaceRaised = const Color(0xFFF0F0F3); // inner raised elements

  // ── Primary (near-black) ──────────────────────────────────────────
  static Color primary      = const Color(0xFF111111);
  static Color primaryLight = const Color(0xFF444444);
  static Color primaryFaint = const Color(0x0D111111);

  // ── Accent – completion green ─────────────────────────────────────
  static Color complete     = const Color(0xFF4CD964);
  static Color completeFill = const Color(0xFFE8F8ED);

  // ── Nav ───────────────────────────────────────────────────────────
  static Color navBackground = const Color(0xFF111111);
  static Color navActive     = const Color(0xFFFFFFFF);
  static Color navInactive   = const Color(0xFF888888);

  // ── Borders & text ────────────────────────────────────────────────
  static Color border         = const Color(0xFFE8E8E8);
  static Color textPrimary    = const Color(0xFF1A1A1A);
  static Color textSecondary  = const Color(0xFF666666);
  static Color textMuted      = const Color(0xFF9E9E9E);

  // ── Streak ───────────────────────────────────────────────────────
  static Color streak     = const Color(0xFF111111);
  static Color streakFill = const Color(0xFFF5F5F5);

  // ── Priority (Focus Matrix) ───────────────────────────────────────
  static const Color p1 = Color(0xFFEF4444);
  static const Color p2 = Color(0xFFF59E0B);
  static const Color p3 = Color(0xFF3B82F6);
  static const Color p4 = Color(0xFF8B5CF6);
  static const Color p5 = Color(0xFF10B981);

  // ── Day strip ────────────────────────────────────────────────────
  static Color dayActive     = const Color(0xFF111111);
  static Color dayActiveTxt  = const Color(0xFFFFFFFF);
  static Color dayInactiveTxt= const Color(0xFF9E9E9E);

  // ── Session segment colours ───────────────────────────────────────
  static Color worship    = const Color(0xFF7C5CBF);
  static Color build      = const Color(0xFF3D6FD4);
  static Color morning    = const Color(0xFFD44060);
  static Color midMorning = const Color(0xFF5058D0);
  static Color midday     = const Color(0xFF4CD964);
  static Color afternoon  = const Color(0xFFF5A623);
  static Color sunset     = const Color(0xFFD46820);
  static Color evening    = const Color(0xFF1AA898);

  // ── Misc ─────────────────────────────────────────────────────────
  static Color tipBackground   = const Color(0xFFFFF8E1);
  static Color bonusBackground = const Color(0xFFE8F8ED);

  static Color moodLow  = const Color(0xFFD44060);
  static Color moodMid  = const Color(0xFF111111);
  static Color moodHigh = const Color(0xFF4CD964);

  // ── card decoration (white + subtle shadow) ───────────────────────
  /// Use this on every card Container instead of a raw BoxDecoration.
  /// Change shadows in ONE place → entire app updates.
  static BoxDecoration cardDecoration({
    double radius = 20,
    Color? color,
    Border? border,
  }) =>
      BoxDecoration(
        color: color ?? cardSurface,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000), // 4 % opacity black
            blurRadius: 16,
            spreadRadius: 0,
            offset: Offset(0, 4),
          ),
        ],
        border: border,
      );
}
