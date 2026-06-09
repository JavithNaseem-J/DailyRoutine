abstract final class FallbackQuotes {
  static const list = [
    (
      text: "The present moment is filled with joy and happiness. If you are attentive, you will see it.",
      author: "Thich Nhat Hanh"
    ),
    (
      text: "Start where you are. Use what you have. Do what you can.",
      author: "Arthur Ashe"
    ),
    (
      text: "Do not dwell in the past, do not dream of the future, concentrate the mind on the present moment.",
      author: "Buddha"
    ),
    (
      text: "Mindfulness isn't difficult, we just need to remember to do it.",
      author: "Sharon Salzberg"
    ),
    (
      text: "Continuous effort - not strength or intelligence - is the key to unlocking our potential.",
      author: "Winston Churchill"
    ),
    (
      text: "You must be the change you wish to see in the world.",
      author: "Mahatma Gandhi"
    ),
    (
      text: "Life is not a problem to be solved, but a reality to be experienced.",
      author: "Søren Kierkegaard"
    ),
    (
      text: "In the middle of difficulty lies opportunity.",
      author: "Albert Einstein"
    ),
  ];

  static ({String text, String author}) getTodayQuote() {
    final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
    final index = dayOfYear % list.length;
    return list[index];
  }
}
