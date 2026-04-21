# Daily Routine App — Implementation Plan v2

> **Last updated**: 2026-04-16
> **Status**: Phase 6 (UI Polish + New Features) — COMPLETE ✅  
> **Build**: `flutter analyze` → No issues found ✅

---

## Phase Summary

| Phase | Status | What was done |
|---|---|---|
| **Phase 1** — Setup + Foundation | **COMPLETE ✅** | Flutter project, 13 deps, theme, models, services, 8 Supabase tables |
| **Phase 2** — Stitch Design | **SKIPPED** | User building directly in Flutter — no Stitch needed |
| **Phase 3** — Feature Build | **COMPLETE ✅** | UI + full Hive/Supabase persistence wired, Riverpod 3.x provider |
| **Phase 4** — Logic + Notifications | **COMPLETE ✅** | Streak, midnight reset, notifications, Settings screen |
| **Phase 5** — Polish + Device Test | **COMPLETE ✅** | Manifest, real stats data, hive/notification web guards |
| **Phase 6** — UI Polish + New Features | **COMPLETE ✅** | Neo-Brutalist UI rework, In Progress cards, Pre-Plan popups |

---

## Supabase Project
- **Project ID**: `rbfzonbeqytzkdomcfev`
- **URL**: `https://rbfzonbeqytzkdomcfev.supabase.co`
- **Anon key**: in `lib/main.dart`

---

## Architecture Notes
- **State**: Riverpod 3.x `AsyncNotifier` in `sessions_provider.dart`
- **Local cache**: Hive (mobile only) — web-safe (nullable boxes, `_initialized` guard)
- **Remote**: Supabase (always active, keyed by `deviceId`)
- **Design**: Strict monochrome Neo-Brutalist — `#111111` primary, `#4CD964` complete, NO orange/amber in UI chrome
- **Notifications**: `flutter_local_notifications` v20.x — all named params, mobile only (`kIsWeb` guard)

---

## Key Files
```
app/lib/
├── main.dart                          ← init + kIsWeb guards, sharedPrefs
├── app.dart                           ← routes (ShellRoute + /settings)
├── core/
│   ├── constants/session_data.dart    ← all sessions + tasks
│   ├── models/daily_state.dart        ← taskStates, bonusStates, mood
│   ├── models/quick_task.dart         ← id, date, title, done, archived
│   ├── models/todays_focus.dart       ← session1/2/3 text
│   ├── models/prayer_times.dart       ← fajr/dhuhr/asr/maghrib/isha
│   ├── services/date_service.dart     ← todayKey(), keyFor(), buildWeekStrip()
│   ├── services/hive_service.dart     ← local cache (nullable boxes)
│   ├── services/supabase_service.dart ← all remote calls
│   ├── services/prayer_service.dart   ← getNextPrayer(), getPrayerData()
│   ├── services/streak_service.dart   ← fetchStreak(), onTaskToggled()
│   ├── services/notification_service.dart ← v20 API, kIsWeb guarded
│   ├── services/lifecycle_service.dart    ← midnight rollover observer
│   └── theme/app_colors.dart          ← Neo-Brutalist monochrome palette
├── features/
│   ├── home/home_screen.dart          ← main screen (Contains all Phase 6 UI rework)
│   ├── sessions/sessions_screen.dart  ← task cards + complete banner
│   ├── stats/stats_screen.dart        ← real data wired
│   └── settings/settings_screen.dart ← notification toggles + resets
```

---

## PHASE 6 — UI POLISH (COMPLETE ✅)

The UI was heavily modernized to follow a Neo-Brutalist/Minimalist aesthetic. 

### Final State of Major UI Components:
1. **Greeting Icon**: Left-aligned, session-aware (changes icon based on time of day).
2. **Prayer Card**: Shows Adhaan time and Prayer Start offset time (Maghrib+5m, others+20m). Full 5-prayer row at the bottom with past/next status dots.
3. **Task Board**: Replaced "Quick Add". Features slide-in animations, rounded checkmarks, strike-through styling, and swipe-to-delete.
4. **Daily Goals (Water & Walk)**:
   - Simple Ring trackers. Water (Blue target), Walk (Green target).
   - Shows checkmark icon inside the ring when 100% complete.
   - Saves to `sharedPrefs` based on the current date string so it resets organically at midnight.
5. **In Progress Cards**:
   - Replaced "Today's Focus". Horizontal scrolling cards.
   - **Interaction**: The user drags the *thin bottom progress bar* to update progress. The rest of the card is safe from accidental swipes.
   - **Editing**: Long-pressing the card opens a bottom sheet to Edit or Delete.
   - **UI**: Task Name and % align perfectly horizontally. Heights are compressed (140px) for a sleeker profile.
6. **Date Picker & Pre-Plan**:
   - The user can long-press dates in the future on the top calendar strip to add a "Pre-Plan".
   - A red dot appears in the upper-right corner of the date circle if a plan exists.
   - Tapping a planned date opens a floating `GeneralDialog` (Tooltip) under the strip displaying the plan. 
   - No hint text or heavy background colors on inputs.

---

## Important Notes for Next Model (Phase 7 / Maintenance)
1. **Services are Singletons**: Access via lowercase name: `hiveService`, `supabaseService`, `prayerService`, `streakService`, `notificationService`, `lifecycleService`, `dateService`.
2. **Global Variables**: `deviceId` and `sharedPrefs` are global `late` variables in `main.dart`. Import with `import '../../main.dart' show deviceId, sharedPrefs`.
3. **State Management**: Riverpod `AsyncNotifier`. Watch with `ref.watch(sessionsProvider)`. Local UI state is handled heavily within `HomeScreen` via `setState()` for transient interactions.
4. **Theming**: `AppColors.complete` = `#4CD964` (green). `AppColors.primary` = `#111111`. NO generic colors, maintain the stark, high-contrast Neo-Brutalist look.
5. **Testing**: Run `flutter analyze` after every Dart change! Maintain 0 issues.
