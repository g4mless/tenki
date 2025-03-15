import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/weather.dart';

class WeatherService {
  static const baseUrl = 'https://api.open-meteo.com/v1';
  static const geoUrl = 'https://geocoding-api.open-meteo.com/v1';

  WeatherService({String? apiKey});

  Future<List<Map<String, dynamic>>> _searchLocation(String city) async {
    final response = await http.get(
      Uri.parse('$geoUrl/search?name=$city&count=1&language=en&format=json'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['results'] ?? []);
    }
    throw Exception('Failed to find location');
  }

  Future<Weather?> getWeather(String city) async {
    final locations = await _searchLocation(city);
    if (locations.isEmpty) return null;

    final location = locations.first;
    return getWeatherFromCoordinates(
      location['latitude'],
      location['longitude'],
      cityName: location['name'],
    );
  }

  Future<List<Weather>> getForecast(String city) async {
    final locations = await _searchLocation(city);
    if (locations.isEmpty) return [];

    final location = locations.first;
    return getForecastFromCoordinates(
      location['latitude'],
      location['longitude'],
      cityName: location['name'],
    );
  }

  Future<Weather> getWeatherFromCoordinates(
    double lat,
    double lon, {
    String cityName = 'Current Location',
  }) async {
    final response = await http.get(Uri.parse(
      '$baseUrl/forecast?latitude=$lat&longitude=$lon'
      '&hourly=temperature_2m,weathercode'
    ));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final times = data['hourly']['time'];
      final temps = data['hourly']['temperature_2m'];
      final codes = data['hourly']['weathercode'];

      // Find current hour's data
      final now = DateTime.now();
      final currentHour = DateTime(now.year, now.month, now.day, now.hour);
      
      for (var i = 0; i < times.length; i++) {
        final forecastTime = DateTime.parse(times[i]);
        if (forecastTime.isAtSameMomentAs(currentHour)) {
          return Weather.fromOpenMeteo({
            'temperature_2m': temps[i],
            'weathercode': codes[i],
          }, cityName);
        }
      }
      throw Exception('Current hour data not found');
    }
    throw Exception('Failed to load weather');
  }

  Future<List<Weather>> getForecastFromCoordinates(
    double lat,
    double lon, {
    String cityName = 'Current Location',
  }) async {
    final response = await http.get(Uri.parse(
      '$baseUrl/forecast?latitude=$lat&longitude=$lon'
      '&hourly=temperature_2m,weathercode'
    ));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<Weather> forecast = [];
      
      final times = data['hourly']['time'];
      final temps = data['hourly']['temperature_2m'];
      final codes = data['hourly']['weathercode'];

      final now = DateTime.now();
      final currentHour = DateTime(now.year, now.month, now.day, now.hour);

      for (var i = 0; i < times.length; i++) {
        final forecastTime = DateTime.parse(times[i]);
        if (forecastTime.isBefore(currentHour)) continue;

        forecast.add(Weather.fromOpenMeteo({
          'temperature_2m': temps[i],
          'weathercode': codes[i],
          'time': times[i],
        }, cityName));
      }

      return forecast;
    }
    throw Exception('Failed to load forecast');
  }
}