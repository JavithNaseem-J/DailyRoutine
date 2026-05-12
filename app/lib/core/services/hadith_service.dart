import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../../main.dart' show sharedPrefs;
import '../constants/hadiths.dart';

class HadithData {
  final String text;
  final String attribution;

  HadithData({required this.text, required this.attribution});

  Map<String, dynamic> toJson() => {
        'text': text,
        'attribution': attribution,
      };

  factory HadithData.fromJson(Map<String, dynamic> j) => HadithData(
        text: j['text'] ?? '',
        attribution: j['attribution'] ?? '',
      );
}

class HadithService {
  static final HadithService _instance = HadithService._();
  factory HadithService() => _instance;
  HadithService._();

  Future<HadithData> getDailyHadith({bool forceRefresh = false}) async {
    final lastFetch = sharedPrefs.getInt('hadith_last_fetch') ?? 0;
    final cachedStr = sharedPrefs.getString('hadith_data_json');
    
    final now = DateTime.now();
    // Cache until midnight (start of next day)
    final lastFetchDate = DateTime.fromMillisecondsSinceEpoch(lastFetch);
    final isSameDay = now.year == lastFetchDate.year &&
        now.month == lastFetchDate.month &&
        now.day == lastFetchDate.day;

    if (!forceRefresh && cachedStr != null && isSameDay) {
      try {
        return HadithData.fromJson(jsonDecode(cachedStr));
      } catch (_) {}
    }

    try {
      // Try up to 3 times to find a short hadith to ensure it fits the UI card
      for (int i = 0; i < 3; i++) {
        final book = Random().nextInt(97) + 1;
        final url = 'https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions/eng-bukhari/sections/$book.json';
        
        final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 3));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final hadiths = data['hadiths'] as List;
          
          // Filter for short hadiths (max ~4 lines)
          final shortHadiths = hadiths.where((h) {
            String t = h['text'].toString().replaceAll(RegExp(r'<[^>]*>'), '').trim();
            return t.length > 20 && t.length <= 250;
          }).toList();

          if (shortHadiths.isNotEmpty) {
            final randomHadith = shortHadiths[Random().nextInt(shortHadiths.length)];
            String text = randomHadith['text'].toString().replaceAll(RegExp(r'<[^>]*>'), '').trim();
            
            final hadithNumber = randomHadith['hadithnumber'];
            final attribution = 'Sahih al-Bukhari $hadithNumber';

            final result = HadithData(text: text, attribution: attribution);
            
            // Save cache
            await sharedPrefs.setString('hadith_data_json', jsonEncode(result.toJson()));
            await sharedPrefs.setInt('hadith_last_fetch', now.millisecondsSinceEpoch);
            return result;
          }
        }
      }
    } catch (e) {
      // Fallback to local
    }

    // Fallback to local constant list if API fails
    final fallback = Hadiths.today();
    return HadithData(text: fallback.text, attribution: fallback.attribution);
  }
}

final hadithService = HadithService();
