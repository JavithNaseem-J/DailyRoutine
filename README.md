# Yawmi --- The Mindful Daily Routine Planner

Yawmi (Arabic for "My Day") is a beautifully designed, high-performance daily routine planner built with Flutter. It seamlessly merges deep-work concepts, Islamic prayer rhythms, and a local-first offline architecture into a single cohesive experience.

Designed for those who want to reclaim their focus, Yawmi breaks the day into manageable sessions, prioritizes tasks via an Eisenhower-style Focus Matrix, and keeps track of habits and prayers seamlessly.

---

## ✨ Key Features

- **Time-Blocked Sessions:** Structure your day around meaningful time blocks (Morning, Midday, Afternoon, Sunset, Evening). Each session has its own dedicated focus space.
- **The Focus Matrix:** An advanced 4-quadrant task manager limiting you to 5 critical tasks per quadrant, categorized by priority (P1–P5) with visual color-coding.
- **Prayer Integrations:** Built-in automatic prayer times calculated based on location (using the Muslim World League algorithm) with a beautiful visual timeline and 10-minute alerts.
- **Local-First Architecture:** Instant interactions and zero loading spinners. Data is written to local storage (Hive) immediately and synchronized in the background to Supabase.
- **Pomodoro Deep Focus:** A dedicated timer screen with ambient sounds (rain, cafe, noise), allowing you to log deep work directly against your active projects.
- **Rich Analytics:** Track your performance with heatmap activity graphs, weekly focus charts, and streak counters.

---

## 🛠 Tech Stack & Architecture

- **Frontend:** Flutter (`^3.9.0`), Dart
- **State Management:** Riverpod 3 (`flutter_riverpod`)
- **Navigation:** GoRouter (with ShellRoute for bottom navigation)
- **Local Database:** Hive (fast, write-ahead caching) & SharedPreferences
- **Backend Sync:** Supabase (PostgreSQL, Email/Password & Anonymous Auth, Row Level Security)
- **Crash Reporting:** Sentry
- **Key Plugins:** `fl_chart`, `adhan`, `flutter_local_notifications`, `geolocator`, `audioplayers`

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (`^3.9.0` or higher)
- Android Studio / Xcode
- A Supabase project (for backend sync)
- A Sentry project (for crash reporting)

### 1. Clone the repository
```bash
git clone https://github.com/yourusername/Yawmi.git
cd Yawmi/app
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Supabase Setup
1. Create a new project on [Supabase](https://supabase.com).
2. Go to **Authentication -> Configuration** and enable **Anonymous Sign-ins** (required for local-first seamless usage before users create an account).
3. Run the SQL schema found in `artifacts/full_audit_report.md` in the Supabase SQL Editor to provision tables and RLS policies.

### 4. Run the App
To run the app locally, you must pass in your environment variables via `--dart-define`:

```bash
flutter run \
  --dart-define=SUPABASE_URL="https://your-project-id.supabase.co" \
  --dart-define=SUPABASE_ANON_KEY="your-anon-key" \
  --dart-define=SENTRY_DSN="https://your-dsn@sentry.io/id"
```

> **Tip:** In VS Code, you can add these to your `launch.json` so you don't have to type them every time.

---

## 📦 Building for Production (Android)

Yawmi is hardened for production release with RLS policies, code obfuscation, and crash monitoring.

1. Generate your release keystore and place it in the `android/` directory:
   ```bash
   keytool -genkey -v -keystore yawmi-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias yawmi
   ```
2. Create `android/key.properties` with your keystore credentials:
   ```properties
   storePassword=your_password
   keyPassword=your_password
   keyAlias=yawmi
   storeFile=yawmi-release.jks
   ```
3. Build the release APK:
   ```bash
   flutter build apk --release \
     --dart-define=SUPABASE_URL="..." \
     --dart-define=SUPABASE_ANON_KEY="..." \
     --dart-define=SENTRY_DSN="..."
   ```

---

## 🛡️ Architecture & Data Flow

Yawmi follows a strict **offline-first pattern**. 
1. **Reads:** The UI *only* listens to Hive. Hive is the single source of truth for the UI.
2. **Writes:** When a user interacts, the app immediately writes the change to Hive (optimistic UI update).
3. **Syncing:** The app then asynchronously fires an upsert request to Supabase using a unique `device_id` (or authenticated `uid`). If the network fails, the local data remains intact.

---

## 🎨 UI/UX Design Principles
- **Monochrome Foundation:** Core UI elements utilize stark contrasts (`AppColors.primary`, `AppColors.background`) to eliminate visual clutter.
- **Strategic Color:** Colors are exclusively reserved for denoting specific semantics (e.g., Priority flags, prayer active states, or deep-work sessions).
- **Haptic Feedback:** Strategic use of `HapticFeedback` on critical interactions creates a premium, tactile experience.

---

## 👨‍💻 Author

Designed & Engineered by **Naseem**.