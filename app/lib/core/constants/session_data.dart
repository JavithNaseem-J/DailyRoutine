import '../models/session.dart';
import '../theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SESSION DATA — 11 sessions, 40 tasks total (hardcoded V1)
//
// Sessions: Dawn | Sunrise | Morning | Mid-Morning | Midday/Dhuhr |
//           Afternoon | Asr/Sunset | Evening | Night |
//           Friday Review (Fri only) | Sunday Planning (Sun only)
//
// Build sessions with timer: sunrise_build (S1), midmorning_build (S2),
//                             afternoon_build (S3)
// ─────────────────────────────────────────────────────────────────────────────

abstract final class SessionData {
  static List<Session> get allSessions => [
        _dawn,
        _sunrise,
        _morning,
        _midMorning,
        _midday,
        _afternoon,
        _asrSunset,
        _evening,
        _night,
        _fridayReview,
        _sundayPlanning,
      ];

  // ── 1. DAWN  (5:00 – 7:00am) ──────────────────────────────────────
  static const _dawn = Session(
    id: 'dawn',
    name: 'Dawn',
    timeRange: '5:00 – 7:00am',
    accentColor: AppColors.worship,
    tasks: [
      Task(
        id: 'dawn_1',
        sessionId: 'dawn',
        title: 'Fajr Prayer',
        time: '5:00am',
        durationMinutes: 20,
        tip: 'Pray on time — Fajr sets the tone for the entire day.',
        bonus: 'Pray 2 Sunnah rak\'ahs before Fajr fard.',
        ring: RingType.worship,
      ),
      Task(
        id: 'dawn_2',
        sessionId: 'dawn',
        title: 'Morning Adhkar & Dhikr',
        time: '5:25am',
        durationMinutes: 15,
        tip: 'Recite the morning supplications — they protect and energise.',
        bonus: 'Read 1 page of Quran after adhkar.',
        ring: RingType.worship,
      ),
      Task(
        id: 'dawn_3',
        sessionId: 'dawn',
        title: 'Light Stretching / Wudu reset',
        time: '5:45am',
        durationMinutes: 10,
        tip: 'Get your body moving before the desk. 5–10 min is enough.',
        ring: RingType.body,
      ),
      Task(
        id: 'dawn_4',
        sessionId: 'dawn',
        title: 'Morning Planning (review today\'s goals)',
        time: '6:00am',
        durationMinutes: 20,
        tip:
            'Open your notebook. Write the 3 most important things for today.',
        bonus: 'Update Today\'s Focus section in the app.',
        ring: RingType.build,
      ),
    ],
  );

  // ── 2. SUNRISE / Build Session 1  (7:00 – 9:00am) ────────────────
  static const _sunrise = Session(
    id: 'sunrise',
    name: 'Sunrise',
    timeRange: '7:00 – 9:00am',
    accentColor: AppColors.build,
    tasks: [
      Task(
        id: 'sunrise_1',
        sessionId: 'sunrise',
        title: 'Build Session 1',
        time: '7:00am',
        durationMinutes: 60,
        tip: 'Deep work — close all distractions. 1 hour focused block.',
        bonus: 'Write a brief summary of what you built/learned after.',
        subtitle: '', // injected from Today\'s Focus S1
        ring: RingType.build,
        hasSessionTimer: true,
      ),
      Task(
        id: 'sunrise_2',
        sessionId: 'sunrise',
        title: 'LinkedIn Networking Window',
        time: '8:05am',
        durationMinutes: 30,
        tip: 'Reply to connections, comment on 2 posts, send 1 outreach message.',
        bonus: 'Post a short insight or learning from your current project.',
        ring: RingType.build,
      ),
      Task(
        id: 'sunrise_3',
        sessionId: 'sunrise',
        title: 'Breakfast & Break',
        time: '8:40am',
        durationMinutes: 20,
        tip: 'Step away from the screen. Eat mindfully.',
        isBreak: true,
        ring: RingType.body,
      ),
    ],
  );

  // ── 3. MORNING  (9:00 – 11:00am) ─────────────────────────────────
  static const _morning = Session(
    id: 'morning',
    name: 'Morning',
    timeRange: '9:00 – 11:00am',
    accentColor: AppColors.morning,
    tasks: [
      Task(
        id: 'morning_1',
        sessionId: 'morning',
        title: 'English Practice (Speaking/Writing)',
        time: '9:00am',
        durationMinutes: 45,
        tip: 'Shadowing with a podcast, or write a short paragraph on a topic.',
        bonus: 'Record a 2-minute voice note and play it back to review.',
        ring: RingType.build,
      ),
      Task(
        id: 'morning_2',
        sessionId: 'morning',
        title: 'Technical Reading / Podcast',
        time: '9:50am',
        durationMinutes: 30,
        tip: 'One article or 30 min of a technical podcast relevant to ML/AI.',
        bonus: 'Write 3 bullet takeaways in your notebook.',
        ring: RingType.build,
      ),
      Task(
        id: 'morning_3',
        sessionId: 'morning',
        title: 'Short Walk',
        time: '10:25am',
        durationMinutes: 20,
        tip: 'Walk outside if possible — sunlight and movement boost focus.',
        isBreak: true,
        ring: RingType.body,
      ),
    ],
  );

  // ── 4. MID-MORNING / Build Session 2  (11:00am – 12:30pm) ────────
  static const _midMorning = Session(
    id: 'mid_morning',
    name: 'Mid Morning',
    timeRange: '11:00am – 12:30pm',
    accentColor: AppColors.midMorning,
    tasks: [
      Task(
        id: 'midmorning_1',
        sessionId: 'mid_morning',
        title: 'Build Session 2',
        time: '11:00am',
        durationMinutes: 60,
        tip: 'Second deep work block — continue or start a new sub-task.',
        bonus: 'Push your code or update your Notion board after.',
        subtitle: '', // injected from Today\'s Focus S2
        ring: RingType.build,
        hasSessionTimer: true,
      ),
      Task(
        id: 'midmorning_2',
        sessionId: 'mid_morning',
        title: 'Job Application / CV Refinement',
        time: '12:05pm',
        durationMinutes: 25,
        tip: 'Apply to at least 1 job on LinkedIn or a job board.',
        bonus: 'Tailor your CV or cover letter for the role.',
        ring: RingType.build,
      ),
    ],
  );

  // ── 5. MIDDAY / DHUHR  (12:30 – 2:00pm) ─────────────────────────
  static const _midday = Session(
    id: 'midday',
    name: 'Midday',
    timeRange: '12:30 – 2:00pm',
    accentColor: AppColors.midday,
    tasks: [
      Task(
        id: 'midday_1',
        sessionId: 'midday',
        title: 'Dhuhr Prayer',
        time: '12:30pm',
        durationMinutes: 15,
        tip: 'Pray Dhuhr — on Fridays this becomes Jumu\'ah.',
        bonus: 'Pray the 4 Sunnah rak\'ahs before Dhuhr.',
        ring: RingType.worship,
        isFridaySpecial: true, // → "Jumu\'ah Prayer" on Fridays
      ),
      Task(
        id: 'midday_2',
        sessionId: 'midday',
        title: 'Lunch & Proper Rest',
        time: '12:50pm',
        durationMinutes: 40,
        tip: 'Eat a proper meal. No screen during lunch.',
        isBreak: true,
        ring: RingType.body,
      ),
      Task(
        id: 'midday_3',
        sessionId: 'midday',
        title: 'Qaylula (Power Nap)',
        time: '1:35pm',
        durationMinutes: 20,
        tip: '15–20 min nap — a Sunnah. Set a timer so you don\'t oversleep.',
        bonus: 'Do a short dhikr before closing your eyes.',
        ring: RingType.worship,
      ),
    ],
  );

  // ── 6. AFTERNOON / Build Session 3  (2:00 – 4:00pm) ─────────────
  static const _afternoon = Session(
    id: 'afternoon',
    name: 'Afternoon',
    timeRange: '2:00 – 4:00pm',
    accentColor: AppColors.afternoon,
    tasks: [
      Task(
        id: 'afternoon_1',
        sessionId: 'afternoon',
        title: 'Build Session 3',
        time: '2:00pm',
        durationMinutes: 60,
        tip: 'Final deep work block of the day. Finish strong.',
        bonus: 'Write a 3-sentence "today I built / learned / struggled with" note.',
        subtitle: '', // injected from Today\'s Focus S3
        ring: RingType.build,
        hasSessionTimer: true,
      ),
      Task(
        id: 'afternoon_2',
        sessionId: 'afternoon',
        title: 'Applied Practice / Kaggle / LeetCode',
        time: '3:05pm',
        durationMinutes: 40,
        tip: 'One problem or one notebook cell. Consistency beats intensity.',
        bonus: 'Submit a Kaggle competition entry or push a notebook.',
        ring: RingType.build,
      ),
    ],
  );

  // ── 7. ASR / SUNSET  (4:00 – 6:30pm) ────────────────────────────
  static const _asrSunset = Session(
    id: 'asr_sunset',
    name: 'Asr & Sunset',
    timeRange: '4:00 – 6:30pm',
    accentColor: AppColors.sunset,
    tasks: [
      Task(
        id: 'asr_1',
        sessionId: 'asr_sunset',
        title: 'Asr Prayer',
        time: '4:05pm',
        durationMinutes: 15,
        tip: 'Do not delay Asr — it is the middle prayer.',
        bonus: 'Pray 4 Sunnah rak\'ahs before Asr.',
        ring: RingType.worship,
      ),
      Task(
        id: 'asr_2',
        sessionId: 'asr_sunset',
        title: 'Outdoor Walk / Light Exercise',
        time: '4:25pm',
        durationMinutes: 40,
        tip: 'Walk outside — Dubai evenings are great after 4pm.',
        bonus: 'Do a 10-minute body-weight workout before the walk.',
        ring: RingType.body,
      ),
      Task(
        id: 'asr_3',
        sessionId: 'asr_sunset',
        title: 'Pre-Maghrib Quran / Dhikr',
        time: '5:50pm',
        durationMinutes: 20,
        tip: 'The time before Maghrib is blessed. Recite your evening adhkar.',
        bonus: 'Read half a page of Quran and reflect on the meaning.',
        ring: RingType.worship,
      ),
    ],
  );

  // ── 8. EVENING  (6:30 – 8:30pm) ──────────────────────────────────
  static const _evening = Session(
    id: 'evening',
    name: 'Evening',
    timeRange: '6:30 – 8:30pm',
    accentColor: AppColors.evening,
    tasks: [
      Task(
        id: 'evening_1',
        sessionId: 'evening',
        title: 'Maghrib Prayer',
        time: '6:30pm',
        durationMinutes: 15,
        tip: 'Pray Maghrib at the correct time — do not delay it.',
        bonus: 'Pray 2 Sunnah rak\'ahs after Maghrib.',
        ring: RingType.worship,
      ),
      Task(
        id: 'evening_2',
        sessionId: 'evening',
        title: 'Dinner with Family / Social Time',
        time: '6:50pm',
        durationMinutes: 45,
        tip: 'Be present. Put the phone away during family time.',
        isBreak: true,
        ring: RingType.none,
      ),
      Task(
        id: 'evening_3',
        sessionId: 'evening',
        title: 'Review Job Applications & Responses',
        time: '7:40am',
        durationMinutes: 30,
        tip: 'Check your email and LinkedIn. Reply to any recruiter messages.',
        bonus: 'Follow up on any pending application if 5+ days have passed.',
        ring: RingType.build,
      ),
    ],
  );

  // ── 9. NIGHT  (8:30 – 10:30pm) ───────────────────────────────────
  static const _night = Session(
    id: 'night',
    name: 'Night',
    timeRange: '8:30 – 10:30pm',
    accentColor: AppColors.evening,
    tasks: [
      Task(
        id: 'night_1',
        sessionId: 'night',
        title: 'Isha Prayer',
        time: '8:30pm',
        durationMinutes: 20,
        tip: 'Pray Isha — do not sleep before praying it.',
        bonus: 'Pray Witr after Isha.',
        ring: RingType.worship,
      ),
      Task(
        id: 'night_2',
        sessionId: 'night',
        title: 'Evening Reflection / Journaling',
        time: '8:55pm',
        durationMinutes: 20,
        tip: 'Write 3 things: what you did, what you learned, what you\'ll do differently.',
        bonus: 'Note one thing you are grateful for today.',
        ring: RingType.build,
      ),
      Task(
        id: 'night_3',
        sessionId: 'night',
        title: 'Evening Adhkar',
        time: '9:20pm',
        durationMinutes: 15,
        tip: 'Recite the evening adhkar — protection for the night.',
        ring: RingType.worship,
      ),
      Task(
        id: 'night_4',
        sessionId: 'night',
        title: 'Sleep Preparation (screens off)',
        time: '9:40pm',
        durationMinutes: 30,
        tip: 'Dim lights, stop screens 30 min before sleep. Sleep by 10:30pm.',
        bonus: 'Read a physical book (not screen) until drowsy.',
        isBreak: true,
        ring: RingType.body,
      ),
    ],
  );

  // ── 10. FRIDAY REVIEW  (Fridays only) ─────────────────────────────
  static const _fridayReview = Session(
    id: 'friday_review',
    name: 'Friday Review',
    timeRange: '1:30 – 3:00pm',
    accentColor: AppColors.worship,
    isFridayOnly: true,
    tasks: [
      Task(
        id: 'friday_1',
        sessionId: 'friday_review',
        title: 'Jumu\'ah Preparation',
        time: '1:00pm',
        durationMinutes: 30,
        tip: 'Make ghusl, wear clean clothes, recite Surah Al-Kahf.',
        bonus: 'Send salawat on the Prophet ﷺ 100 times.',
        ring: RingType.worship,
        isFridayOnly: true,
      ),
      Task(
        id: 'friday_2',
        sessionId: 'friday_review',
        title: 'Weekly Review (Goals & Progress)',
        time: '1:35pm',
        durationMinutes: 40,
        tip: 'Review this week\'s completions. What went well, what didn\'t?',
        bonus: 'Update your LinkedIn with a weekly reflection post.',
        ring: RingType.build,
        isFridayOnly: true,
      ),
      Task(
        id: 'friday_3',
        sessionId: 'friday_review',
        title: 'Next Week Planning',
        time: '2:20pm',
        durationMinutes: 30,
        tip: 'Set 3 main goals for next week. Block your build sessions.',
        ring: RingType.build,
        isFridayOnly: true,
      ),
    ],
  );

  // ── 11. SUNDAY PLANNING  (Sundays only) ───────────────────────────
  static const _sundayPlanning = Session(
    id: 'sunday_planning',
    name: 'Sunday Planning',
    timeRange: '9:00 – 10:30am',
    accentColor: AppColors.worship,
    isSundayOnly: true,
    tasks: [
      Task(
        id: 'sunday_1',
        sessionId: 'sunday_planning',
        title: 'Weekly Goal Setting',
        time: '9:00am',
        durationMinutes: 30,
        tip: 'Set your 3 most important outcomes for this week.',
        bonus: 'Connect each goal back to your 90-day career target.',
        ring: RingType.build,
        isSundayOnly: true,
      ),
      Task(
        id: 'sunday_2',
        sessionId: 'sunday_planning',
        title: 'Workspace & Environment Prep',
        time: '9:35am',
        durationMinutes: 20,
        tip: 'Clean desk, charge devices, prepare tomorrow\'s outfit.',
        ring: RingType.none,
        isSundayOnly: true,
      ),
      Task(
        id: 'sunday_3',
        sessionId: 'sunday_planning',
        title: 'Social Media / Job Board Research',
        time: '10:00am',
        durationMinutes: 30,
        tip: 'Browse new job postings, save roles, research target companies.',
        bonus: 'Send 3 connection requests to ML/AI professionals in Dubai.',
        ring: RingType.build,
        isSundayOnly: true,
      ),
    ],
  );

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Get a session by id.
  static Session? getById(String id) {
    try {
      return allSessions.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Sessions visible for the current day (filtering Fri/Sun only).
  static List<Session> sessionsForToday({bool isFriday = false, bool isSunday = false}) {
    return allSessions.where((s) {
      if (s.isFridayOnly && !isFriday) return false;
      if (s.isSundayOnly && !isSunday) return false;
      return true;
    }).toList();
  }

  /// All task ids across all sessions (for total count).
  static List<String> get allTaskIds =>
      allSessions.expand((s) => s.tasks.map((t) => t.id)).toList();

  /// Task ids visible today (respecting Fri/Sun constraints).
  static List<String> taskIdsForToday({bool isFriday = false, bool isSunday = false}) {
    return sessionsForToday(isFriday: isFriday, isSunday: isSunday)
        .expand((s) => s.tasks
            .where((t) {
              if (t.isFridayOnly && !isFriday) return false;
              if (t.isSundayOnly && !isSunday) return false;
              return true;
            })
            .map((t) => t.id))
        .toList();
  }
}
