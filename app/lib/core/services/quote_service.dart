import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../main.dart' show sharedPrefs;
import '../constants/quotes.dart';

class QuoteData {
  final String text;
  final String author;

  QuoteData({required this.text, required this.author});

  Map<String, dynamic> toJson() => {
        'text': text,
        'author': author,
      };

  factory QuoteData.fromJson(Map<String, dynamic> j) => QuoteData(
        text: j['text'] ?? '',
        author: j['author'] ?? '',
      );
}

class QuoteService {
  static final QuoteService _instance = QuoteService._();
  factory QuoteService() => _instance;
  QuoteService._();

  Future<QuoteData> getDailyQuote({bool forceRefresh = false}) async {
    final lastFetch = sharedPrefs.getInt('quote_last_fetch') ?? 0;
    final cachedStr = sharedPrefs.getString('quote_data_json');
    
    final now = DateTime.now();
    // Cache until midnight (start of next day)
    final lastFetchDate = DateTime.fromMillisecondsSinceEpoch(lastFetch);
    final isSameDay = now.year == lastFetchDate.year &&
        now.month == lastFetchDate.month &&
        now.day == lastFetchDate.day;

    if (!forceRefresh && cachedStr != null && isSameDay) {
      try {
        return QuoteData.fromJson(jsonDecode(cachedStr));
      } catch (_) {}
    }

    try {
      final response = await http
          .get(Uri.parse('https://zenquotes.io/api/today'))
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          final first = data.first;
          final text = first['q']?.toString().trim() ?? '';
          final author = first['a']?.toString().trim() ?? 'Unknown';

          if (text.isNotEmpty) {
            final result = QuoteData(text: text, author: author);
            await sharedPrefs.setString('quote_data_json', jsonEncode(result.toJson()));
            await sharedPrefs.setInt('quote_last_fetch', now.millisecondsSinceEpoch);
            return result;
          }
        }
      }
    } catch (_) {
      // Fallback below
    }

    final fallback = FallbackQuotes.getTodayQuote();
    return QuoteData(text: fallback.text, author: fallback.author);
  }
}

final quoteService = QuoteService();
