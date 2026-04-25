import 'package:adhan/adhan.dart' as adhan;
import '../models/prayer_times.dart';
import '../../main.dart' show sharedPrefs;
import 'package:flutter/material.dart';

class PrayerService {
  PrayerTimes getPrayerTimesForDate(DateTime date) {
    bool isManual = (sharedPrefs.getString('prayer_mode') ?? 'auto') == 'manual';
    
    if (isManual) {
      return _getManualPrayerTimes(date);
    } else {
      return _getAutomaticPrayerTimes(date);
    }
  }

  PrayerTimes _getAutomaticPrayerTimes(DateTime date) {
    double lat = sharedPrefs.getDouble('prayer_lat') ?? 25.2048;
    double lng = sharedPrefs.getDouble('prayer_lng') ?? 55.2708;
    
    adhan.CalculationParameters params = adhan.CalculationMethod.muslim_world_league.getParameters();
    params.madhab = adhan.Madhab.shafi;

    final coords = adhan.Coordinates(lat, lng);
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

  PrayerTimes _getManualPrayerTimes(DateTime date) {
    DateTime parseTime(String key, String defaultTime) {
      final timeStr = sharedPrefs.getString(key) ?? defaultTime;
      final parts = timeStr.split(':');
      int h = int.tryParse(parts[0]) ?? 0;
      int m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
      return DateTime(date.year, date.month, date.day, h, m);
    }

    return PrayerTimes(
      fajr: parseTime('manual_fajr', '05:00'),
      dhuhr: parseTime('manual_dhuhr', '12:30'),
      asr: parseTime('manual_asr', '15:45'),
      maghrib: parseTime('manual_maghrib', '18:15'),
      isha: parseTime('manual_isha', '19:30'),
      isOverride: true,
    );
  }

  PrayerTimes getTodayPrayerTimes({PrayerTimes? overrides}) {
    return getPrayerTimesForDate(DateTime.now());
  }

  ({String name, DateTime adhaan, DateTime prayerStart}) getPrayerData(
    DateTime now, {
    PrayerTimes? overrides,
  }) {
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

    final tomorrow = getPrayerTimesForDate(now.add(const Duration(days: 1)));
    return (
      name: 'Fajr',
      adhaan: tomorrow.fajr,
      prayerStart: tomorrow.fajr.add(const Duration(minutes: 20)),
    );
  }
}

final prayerService = PrayerService();
