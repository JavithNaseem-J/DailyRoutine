import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../main.dart' show sharedPrefs;

class WeatherData {
  final int temp;
  final String condition;
  final int feelsLike;
  final int humidity;
  final int code;

  WeatherData({
    required this.temp,
    required this.condition,
    required this.feelsLike,
    required this.humidity,
    required this.code,
  });

  Map<String, dynamic> toJson() => {
        'temp': temp,
        'condition': condition,
        'feelsLike': feelsLike,
        'humidity': humidity,
        'code': code,
      };

  factory WeatherData.fromJson(Map<String, dynamic> j) => WeatherData(
        temp: j['temp'] ?? 0,
        condition: j['condition'] ?? '',
        feelsLike: j['feelsLike'] ?? 0,
        humidity: j['humidity'] ?? 0,
        code: j['code'] ?? 0,
      );
}

class WeatherService {
  static final WeatherService _instance = WeatherService._();
  factory WeatherService() => _instance;
  WeatherService._();

  String _getWeatherDescription(int code) {
    switch (code) {
      case 0:
        return 'Clear skies';
      case 1:
      case 2:
      case 3:
        return 'Partly cloudy';
      case 45:
      case 48:
        return 'Foggy';
      case 51:
      case 53:
      case 55:
        return 'Light drizzle';
      case 56:
      case 57:
        return 'Freezing drizzle';
      case 61:
      case 63:
      case 65:
        return 'Rainy';
      case 66:
      case 67:
        return 'Freezing rain';
      case 71:
      case 73:
      case 75:
        return 'Snowfall';
      case 77:
        return 'Snow grains';
      case 80:
      case 81:
      case 82:
        return 'Rain showers';
      case 85:
      case 86:
        return 'Snow showers';
      case 95:
      case 96:
      case 99:
        return 'Thunderstorms';
      default:
        return 'Clear skies';
    }
  }

  Future<WeatherData?> getWeatherData({bool forceRefresh = false}) async {
    double lat = sharedPrefs.getDouble('prayer_lat') ?? 25.2048; // Dubai default
    double lng = sharedPrefs.getDouble('prayer_lng') ?? 55.2708;

    final cachedLat = sharedPrefs.getDouble('weather_cached_lat');
    final cachedLng = sharedPrefs.getDouble('weather_cached_lng');

    bool locationChanged = false;
    if (cachedLat != null && cachedLng != null) {
      if ((cachedLat - lat).abs() > 0.01 || (cachedLng - lng).abs() > 0.01) {
        locationChanged = true;
      }
    }

    final lastFetch = sharedPrefs.getInt('weather_last_fetch') ?? 0;
    final cachedStr = sharedPrefs.getString('weather_data_json');
    
    final now = DateTime.now().millisecondsSinceEpoch;
    
    // Check if cache is valid (within 30 minutes) AND location hasn't changed
    if (!forceRefresh && cachedStr != null && !locationChanged && (now - lastFetch < 30 * 60 * 1000)) {
      try {
        return WeatherData.fromJson(jsonDecode(cachedStr));
      } catch (_) {}
    }

    try {

      final url = Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lng&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code&timezone=auto');

      final response = await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final current = data['current'];
        
        if (current != null) {
          final temp = (current['temperature_2m'] as num).round();
          final feelsLike = (current['apparent_temperature'] as num).round();
          final humidity = (current['relative_humidity_2m'] as num).round();
          final code = current['weather_code'] as int;
          
          final condition = _getWeatherDescription(code);
          
          final wData = WeatherData(
            temp: temp,
            condition: condition,
            feelsLike: feelsLike,
            humidity: humidity,
            code: code,
          );
          
          await sharedPrefs.setString('weather_data_json', jsonEncode(wData.toJson()));
          await sharedPrefs.setInt('weather_last_fetch', now);
          await sharedPrefs.setDouble('weather_cached_lat', lat);
          await sharedPrefs.setDouble('weather_cached_lng', lng);
          
          return wData;
        }
      }
    } catch (e) {
      // Silently fail
    }

    if (cachedStr != null) {
      try {
        return WeatherData.fromJson(jsonDecode(cachedStr));
      } catch (_) {}
    }
    
    return null; // Return null if totally offline/no cache
  }
}

final weatherService = WeatherService();
