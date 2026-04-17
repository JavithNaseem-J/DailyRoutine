import 'package:flutter/material.dart';

/// AppColors — all colour tokens derived from the reference UI.
///
/// Palette: white background, amber-orange primary, green progress,
/// dark bottom nav. Session accents match the original design spec.
abstract final class AppColors {
  // ── Backgrounds ──────────────────────────────────────────────────
  static const background    = Color(0xFFFFFFFF); // pure white
  static const cardSurface   = Color(0xFFF5F5F5); // light grey card
  static const surfaceRaised = Color(0xFFEBEBEB); // slightly darker grey

  // ── Primary — sleek modern black (replacing amber)
  static const primary       = Color(0xFF111111);  // near-black
  static const primaryLight  = Color(0xFF444444);  // dark grey
  static const primaryFaint  = Color(0x0D111111);  // black 5% opacity

  // ── Progress / Completion — green ────────────────────────────────
  static const complete      = Color(0xFF4CD964); // fresh green
  static const completeFill  = Color(0xFFE8F8ED); // green tint bg

  // ── Navigation ───────────────────────────────────────────────────
  static const navBackground = Color(0xFF111111); // near-black nav bar
  static const navActive     = Color(0xFFFFFFFF); // white active icon
  static const navInactive   = Color(0xFF888888); // grey inactive

  // ── Borders & Text ───────────────────────────────────────────────
  static const border        = Color(0xFFE5E5E5);
  static const textPrimary   = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF666666);
  static const textMuted     = Color(0xFF9E9E9E);

  // ── Streak ───────────────────────────────────────────────────────
  static const streak        = Color(0xFF111111);  // black
  static const streakFill    = Color(0xFFF5F5F5);

  // ── Day-strip ────────────────────────────────────────────────────
  static const dayActive     = Color(0xFF111111); // selected day circle
  static const dayActiveTxt  = Color(0xFFFFFFFF); // text on selected day
  static const dayInactiveTxt= Color(0xFF9E9E9E);

  // ── Session accent colours ───────────────────────────────────────
  static const worship    = Color(0xFF7C5CBF); // violet — Dawn, Friday, Sunday
  static const build      = Color(0xFF3D6FD4); // blue — Sunrise build sessions
  static const morning    = Color(0xFFD44060); // rose — Morning
  static const midMorning = Color(0xFF5058D0); // indigo — Mid Morning
  static const midday     = Color(0xFF4CD964); // green — Midday/Dhuhr
  static const afternoon  = Color(0xFFF5A623); // amber — Afternoon
  static const sunset     = Color(0xFFD46820); // orange — Sunset/Asr
  static const evening    = Color(0xFF1AA898); // teal — Evening/Night

  // ── Tip / Bonus boxes ────────────────────────────────────────────
  static const tipBackground   = Color(0xFFFFF8E1); // warm amber tint
  static const bonusBackground = Color(0xFFE8F8ED); // green tint

  // ── Mood ─────────────────────────────────────────────────────────
  static const moodLow    = Color(0xFFD44060);  // rose
  static const moodMid    = Color(0xFF111111);  // black
  static const moodHigh   = Color(0xFF4CD964);  // green — high
}
