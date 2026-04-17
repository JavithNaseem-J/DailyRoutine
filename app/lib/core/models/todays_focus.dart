/// TodaysFocus — three build-session focus texts the user sets each morning.
/// Persists per date, clears at midnight. Injected as subtitles into
/// build task cards in the Sessions tab.
class TodaysFocus {
  TodaysFocus({
    required this.date,
    this.session1 = '',
    this.session2 = '',
    this.session3 = '',
  });

  final String date;
  String session1;
  String session2;
  String session3;

  TodaysFocus copyWith({
    String? session1,
    String? session2,
    String? session3,
  }) =>
      TodaysFocus(
        date: date,
        session1: session1 ?? this.session1,
        session2: session2 ?? this.session2,
        session3: session3 ?? this.session3,
      );

  factory TodaysFocus.empty(String date) =>
      TodaysFocus(date: date);

  factory TodaysFocus.fromJson(Map<String, dynamic> json) => TodaysFocus(
        date: json['date'] as String,
        session1: json['session1'] as String? ?? '',
        session2: json['session2'] as String? ?? '',
        session3: json['session3'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'date': date,
        'session1': session1,
        'session2': session2,
        'session3': session3,
      };
}
