import 'package:adhan/adhan.dart' as adhan;
import '../models/prayer_times.dart';

/// PrayerService — wraps the adhan package for Dubai prayer times.
///
/// Coordinates: 25.2048° N, 55.2708° E (Dubai)
/// Method: UAE (CalculationMethod.uae)
/// Works fully offline — no API required.
class PrayerService {
  static const double _lat = 25.2048;
  static const double _lng = 55.2708;

  /// Calculate prayer times for [date] using Dubai coordinates + UAE method.
  PrayerTimes getPrayerTimesForDate(DateTime date) {
    final coords = adhan.Coordinates(_lat, _lng);
    final params = adhan.CalculationMethod.dubai.getParameters();
    params.madhab = adhan.Madhab.hanafi;

    final adhanTimes = adhan.PrayerTimes(
      coords,
      adhan.DateComponents.from(date),
      params,
    );

    return PrayerTimes(
      fajr: adhanTimes.fajr,
      dhuhr: adhanTimes.dhuhr,
      asr: adhanTimes.asr,
      maghrib: adhanTimes.maghrib,
      isha: adhanTimes.isha,
      isOverride: false,
    );
  }

  /// Returns today's prayer times (with optional user overrides applied).
  PrayerTimes getTodayPrayerTimes({PrayerTimes? overrides}) {
    final calculated = getPrayerTimesForDate(DateTime.now());
    if (overrides == null) return calculated;

    final now = DateTime.now();
    DateTime applyOverride(DateTime calculated, DateTime? override) {
      if (override == null) return calculated;
      return DateTime(now.year, now.month, now.day,
          override.hour, override.minute);
    }

    return PrayerTimes(
      fajr: applyOverride(calculated.fajr, overrides.fajr),
      dhuhr: applyOverride(calculated.dhuhr, overrides.dhuhr),
      asr: applyOverride(calculated.asr, overrides.asr),
      maghrib: applyOverride(calculated.maghrib, overrides.maghrib),
      isha: applyOverride(calculated.isha, overrides.isha),
      isOverride: true,
    );
  }

  /// Returns adhaan time + prayer start time for the next prayer.
  /// Offsets: Fajr/Dhuhr/Asr/Isha = +20 min | Maghrib = +5 min.
  ({String name, DateTime adhaan, DateTime prayerStart}) getPrayerData(
      DateTime now, {PrayerTimes? overrides}) {
    final times = getTodayPrayerTimes(overrides: overrides);
    final prayers = times.asOrderedList();

    for (final prayer in prayers) {
      final offset = prayer.name == 'Maghrib'
          ? const Duration(minutes: 5)
          : const Duration(minutes: 20);
      final prayerStart = prayer.time.add(offset);

      if (prayerStart.isAfter(now)) {
        return (
          name: prayer.name,
          adhaan: prayer.time,
          prayerStart: prayerStart,
        );
      }
    }

    // All prayers passed — use tomorrow's Fajr
    final tomorrow = getPrayerTimesForDate(now.add(const Duration(days: 1)));
    return (
      name: 'Fajr',
      adhaan: tomorrow.fajr,
      prayerStart: tomorrow.fajr.add(const Duration(minutes: 20)),
    );
  }
}

/// Singleton instance for use across the app.
final prayerService = PrayerService();
