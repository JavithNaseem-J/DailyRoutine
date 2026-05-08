/// PrayerTimes — holds the five daily prayer times for Dubai.
/// Calculated via the adhan package. isOverride = true when user has
/// manually set a time in Settings, overriding the calculated value.
class PrayerTimes {
  const PrayerTimes({
    required this.fajr,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    this.isOverride = false,
  });

  final DateTime fajr;
  final DateTime dhuhr;
  final DateTime asr;
  final DateTime maghrib;
  final DateTime isha;
  final bool isOverride;

  List<({String name, DateTime time})> asOrderedList() => [
    (name: 'Fajr', time: fajr),
    (name: 'Dhuhr', time: dhuhr),
    (name: 'Asr', time: asr),
    (name: 'Maghrib', time: maghrib),
    (name: 'Isha', time: isha),
  ];
}

/// Mood recorded by the user for a given day.
enum Mood {
  low, // 😔
  mid, // 😐
  high, // 😊
}

extension MoodX on Mood {
  String get emoji {
    switch (this) {
      case Mood.low:
        return '😔';
      case Mood.mid:
        return '😐';
      case Mood.high:
        return '😊';
    }
  }

  String get label {
    switch (this) {
      case Mood.low:
        return 'low';
      case Mood.mid:
        return 'mid';
      case Mood.high:
        return 'high';
    }
  }

  static Mood? fromString(String? s) {
    switch (s) {
      case 'low':
        return Mood.low;
      case 'mid':
        return Mood.mid;
      case 'high':
        return Mood.high;
      default:
        return null;
    }
  }
}
