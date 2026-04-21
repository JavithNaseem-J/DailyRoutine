/// 7 Islamic/motivational quotes — one displayed per day of the week.
/// Index = DateTime.now().weekday % 7  (1=Mon…7=Sun, mod gives 0-6)
abstract final class Quotes {
  static const List<({String text, String attribution})> daily = [
    (
      text: '"Indeed, with hardship will be ease."',
      attribution: '— Quran 94:5',
    ),
    (
      text: '"And whoever relies upon Allah — then He is sufficient for him."',
      attribution: '— Quran 65:3',
    ),
    (
      text:
          '"Take benefit of five before five: your youth before old age, '
          'your health before sickness, your wealth before poverty, '
          'your free time before busyness, and your life before death."',
      attribution: '— Prophet Muhammad ﷺ',
    ),
    (
      text:
          '"The strong person is not the one who can wrestle someone else down. '
          'The strong person is the one who can control himself when he is angry."',
      attribution: '— Prophet Muhammad ﷺ',
    ),
    (
      text: '"Verily, in the remembrance of Allah do hearts find rest."',
      attribution: '— Quran 13:28',
    ),
    (
      text:
          '"Friday is the best of days. It was on this day that Adam was created, '
          'and it is on this day that the Hour will be established."',
      attribution: '— Prophet Muhammad ﷺ',
    ),
    (
      text:
          '"Make things easy and do not make them difficult. '
          'Cheer people up and do not drive them away."',
      attribution: '— Prophet Muhammad ﷺ',
    ),
  ];

  /// Returns today's quote (rotates daily by weekday).
  static ({String text, String attribution}) today() {
    final index = DateTime.now().weekday % 7;
    return daily[index];
  }
}
