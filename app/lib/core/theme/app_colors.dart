import 'package:flutter/material.dart';

/// AppColors — all colour tokens derived from the reference UI.
///
/// Palette: white background, amber-orange primary, green progress,
/// dark bottom nav. Session accents match the original design spec.
abstract final class AppColors {
  // ── Backgrounds ──────────────────────────────────────────────────
  static const Color background = Color(0xFFFFFFFF);
  static const Color cardSurface = Color(0xFFF5F5F5);
  static const Color surfaceRaised = Color(0xFFEBEBEB);

  // ── Primary
  static const Color primary = Color(0xFF111111);
  static const Color primaryLight = Color(0xFF444444);
  static const Color primaryFaint = Color(0x0D111111);

  // ── Progress / Completion — green ────────────────────────────────
  static const Color complete = Color(0xFF4CD964);
  static const Color completeFill = Color(0xFFE8F8ED);

  // ── Navigation ───────────────────────────────────────────────────
  static const Color navBackground = Color(0xFF111111);
  static const Color navActive = Color(0xFFFFFFFF);
  static const Color navInactive = Color(0xFF888888);

  // ── Borders & Text ───────────────────────────────────────────────
  static const Color border = Color(0xFFE5E5E5);
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textMuted = Color(0xFF9E9E9E);

  // ── Streak ───────────────────────────────────────────────────────
  static const Color streak = Color(0xFF111111);
  static const Color streakFill = Color(0xFFF5F5F5);

  // ── Day-strip ────────────────────────────────────────────────────
  static const Color dayActive = Color(0xFF111111);
  static const Color dayActiveTxt = Color(0xFFFFFFFF);
  static const Color dayInactiveTxt = Color(0xFF9E9E9E);

  // ── Session accent colours ───────────────────────────────────────
  static const Color worship = Color(0xFF7C5CBF);
  static const Color build = Color(0xFF3D6FD4);
  static const Color morning = Color(0xFFD44060);
  static const Color midMorning = Color(0xFF5058D0);
  static const Color midday = Color(0xFF4CD964);
  static const Color afternoon = Color(0xFFF5A623);
  static const Color sunset = Color(0xFFD46820);
  static const Color evening = Color(0xFF1AA898);

  // ── Tip / Bonus boxes ────────────────────────────────────────────
  static const Color tipBackground = Color(0xFFFFF8E1);
  static const Color bonusBackground = Color(0xFFE8F8ED);

  // ── Mood ─────────────────────────────────────────────────────────
  static const Color moodLow = Color(0xFFD44060);
  static const Color moodMid = Color(0xFF111111);
  static const Color moodHigh = Color(0xFF4CD964);
}

