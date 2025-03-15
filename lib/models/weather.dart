class Weather {
  final double temperature;
  final String condition;
  final String cityName;
  final DateTime? date;

  Weather({
    required this.temperature,
    required this.condition,
    required this.cityName,
    this.date,
  });

  factory Weather.fromOpenMeteo(Map<String, dynamic> json, String cityName) {
    final weatherCode = json['weathercode'] ?? 0;
    return Weather(
      temperature: (json['temperature_2m'] ?? 0).toDouble(),
      condition: _getWeatherCondition(weatherCode),
      cityName: cityName,
      date: json['time'] != null ? DateTime.parse(json['time']) : null,
    );
  }

  static String _getWeatherCondition(int code) {
    switch (code) {
      case 0:
        return 'Clear';
      case 1:
      case 2:
      case 3:
        return 'Partly Cloudy';
      case 45:
      case 48:
        return 'Foggy';
      case 51:
      case 53:
      case 55:
        return 'Drizzle';
      case 61:
      case 63:
      case 65:
        return 'Rain';
      case 71:
      case 73:
      case 75:
        return 'Snow';
      case 77:
        return 'Snow Grains';
      case 80:
      case 81:
      case 82:
        return 'Rain Showers';
      case 85:
      case 86:
        return 'Snow Showers';
      case 95:
        return 'Thunderstorm';
      case 96:
      case 99:
        return 'Thunderstorm with Hail';
      default:
        return 'Unknown';
    }
  }
}