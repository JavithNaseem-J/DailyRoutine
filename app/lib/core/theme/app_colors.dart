import 'package:flutter/material.dart';

/// AppColors — all colour tokens derived from the reference UI.
///
/// Palette: white background, amber-orange primary, green progress,
/// dark bottom nav. Session accents match the original design spec.
abstract final class AppColors {
  static Color background = const Color(0xFFFFFFFF);
  static Color cardSurface = const Color(0xFFF5F5F5);
  static Color surfaceRaised = const Color(0xFFEBEBEB);

  static Color primary = const Color(0xFF111111);
  static Color primaryLight = const Color(0xFF444444);
  static Color primaryFaint = const Color(0x0D111111);

  static Color complete = const Color(0xFF4CD964);
  static Color completeFill = const Color(0xFFE8F8ED);

  static Color navBackground = const Color(0xFF111111);
  static Color navActive = const Color(0xFFFFFFFF);
  static Color navInactive = const Color(0xFF888888);

  static Color border = const Color(0xFFE5E5E5);
  static Color textPrimary = const Color(0xFF1A1A1A);
  static Color textSecondary = const Color(0xFF666666);
  static Color textMuted = const Color(0xFF9E9E9E);

  static Color streak = const Color(0xFF111111);
  static Color streakFill = const Color(0xFFF5F5F5);

  static Color dayActive = const Color(0xFF111111);
  static Color dayActiveTxt = const Color(0xFFFFFFFF);
  static Color dayInactiveTxt = const Color(0xFF9E9E9E);

  static Color worship = const Color(0xFF7C5CBF);
  static Color build = const Color(0xFF3D6FD4);
  static Color morning = const Color(0xFFD44060);
  static Color midMorning = const Color(0xFF5058D0);
  static Color midday = const Color(0xFF4CD964);
  static Color afternoon = const Color(0xFFF5A623);
  static Color sunset = const Color(0xFFD46820);
  static Color evening = const Color(0xFF1AA898);

  static Color tipBackground = const Color(0xFFFFF8E1);
  static Color bonusBackground = const Color(0xFFE8F8ED);

  static Color moodLow = const Color(0xFFD44060);
  static Color moodMid = const Color(0xFF111111);
  static Color moodHigh = const Color(0xFF4CD964);

  static void init() {
    background = const Color(0xFFFFFFFF);
    cardSurface = const Color(0xFFF5F5F5);
    surfaceRaised = const Color(0xFFEBEBEB);
    
    primary = const Color(0xFF111111);
    primaryLight = const Color(0xFF444444);
    primaryFaint = const Color(0x0D111111);

    navBackground = const Color(0xFF111111);
    navActive = const Color(0xFFFFFFFF);
    navInactive = const Color(0xFF888888);

    border = const Color(0xFFE5E5E5);
    textPrimary = const Color(0xFF1A1A1A);
    textSecondary = const Color(0xFF666666);
    textMuted = const Color(0xFF9E9E9E);
    
    streak = const Color(0xFF111111);
    streakFill = const Color(0xFFF5F5F5);

    dayActive = const Color(0xFF111111);
    dayActiveTxt = const Color(0xFFFFFFFF);
    dayInactiveTxt = const Color(0xFF9E9E9E);

    tipBackground = const Color(0xFFFFF8E1);
    bonusBackground = const Color(0xFFE8F8ED);

    moodMid = const Color(0xFF111111);
  }
}
