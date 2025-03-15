// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';  // Add this import
import 'services/weather_service.dart';
import 'models/weather.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return MaterialApp(
          title: 'Tenki',
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: lightDynamic ?? ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.light,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: darkDynamic ?? ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.dark,
            ),
          ),
          themeMode: ThemeMode.system,
          home: const WeatherPage(),
        );
      },
    );
  }
}

class WeatherPage extends StatefulWidget {
  const WeatherPage({super.key});

  @override
  State<WeatherPage> createState() => _WeatherPageState();
}

class _WeatherPageState extends State<WeatherPage> {
  final WeatherService _weatherService = WeatherService();
  Weather? _weather;
  final TextEditingController _cityController = TextEditingController();
  static const String _lastCityKey = 'last_city';
  List<Weather> _forecast = [];

  @override
  void initState() {
    super.initState();
    _loadLastLocation();
    _loadCurrentLocation();
  }

  Future<void> _loadLastLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final lastLat = prefs.getDouble('last_lat');
    final lastLon = prefs.getDouble('last_lon');
    final lastCity = prefs.getString(_lastCityKey);
    final lastTemp = prefs.getDouble('last_temp');
    final lastCondition = prefs.getString('last_condition');

    if (lastLat != null && lastLon != null && lastCity != null && lastTemp != null && lastCondition != null) {
      setState(() {
        _cityController.text = lastCity;
        _weather = Weather(
          temperature: lastTemp,
          condition: lastCondition,
          cityName: lastCity,
        );
      });

      try {
        final forecast = await _weatherService.getForecastFromCoordinates(lastLat, lastLon);
        setState(() {
          _forecast = forecast;
        });
      } catch (e) {
        // Silent fail for forecast
      }
    } else {
      _loadLastCity();
    }
  }

  Future<void> _loadCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled')),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied')),
          );
          return;
        }
      }

      Position? position;
      int retryCount = 0;
      const maxRetries = 3;

      while (position == null && retryCount < maxRetries) {
        try {
          position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 15),
            ),
          );
          break;
        } catch (e) {
          retryCount++;
          if (retryCount == maxRetries) {
            throw Exception('Could not get location after $maxRetries attempts');
          }
          await Future.delayed(const Duration(seconds: 2));
        }
      }

      if (position == null) {
        throw Exception('Failed to get location');
      }

      try {
        final weather = await _weatherService.getWeatherFromCoordinates(
          position.latitude,
          position.longitude,
        );
        final forecast = await _weatherService.getForecastFromCoordinates(
          position.latitude,
          position.longitude,
        );

        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        String displayName = 'Current Location';
        if (placemarks.isNotEmpty) {
          final place = placemarks[0];
          List<String> locationParts = [];
          
          if (place.locality?.isNotEmpty == true) {
            locationParts.add(place.locality!);
          }
          if (place.subAdministrativeArea?.isNotEmpty == true) {
            locationParts.add(place.subAdministrativeArea!);
          }
          if (place.administrativeArea?.isNotEmpty == true) {
            locationParts.add(place.administrativeArea!);
          }

          displayName = locationParts.isNotEmpty 
              ? locationParts.join(', ')
              : 'Current Location';
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_lastCityKey, displayName);
        await prefs.setDouble('last_lat', position.latitude);
        await prefs.setDouble('last_lon', position.longitude);
        await prefs.setDouble('last_temp', weather.temperature);
        await prefs.setString('last_condition', weather.condition);

        setState(() {
          _cityController.text = displayName;
          _weather = weather;
          _forecast = forecast;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Weather error: ${e.toString()}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location error: ${e.toString()}')),
      );
    }
  }

  Future<void> _loadLastCity() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCity = prefs.getString(_lastCityKey) ?? 'Jakarta';
    setState(() {
      _cityController.text = lastCity;
    });
    _loadWeather();
  }

  Future<void> _loadWeather() async {
    try {
      final weather = await _weatherService.getWeather(_cityController.text);
      final forecast = await _weatherService.getForecast(_cityController.text);
      
      if (weather == null || forecast.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load weather data')),
        );
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastCityKey, _cityController.text);
      setState(() {
        _weather = weather;
        _forecast = forecast;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Weather error: ${e.toString()}')),
      );
    }
  }

  String _getDayName(DateTime date) {
    switch (date.weekday) {
      case 1:
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thu';
      case 5:
        return 'Fri';
      case 6:
        return 'Sat';
      case 7:
        return 'Sun';
      default:
        return '';
    }
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceTint.withAlpha(20),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _cityController,
                          decoration: const InputDecoration(
                            hintText: 'Enter city name',
                            border: InputBorder.none,
                          ),
                          onSubmitted: (_) => _loadWeather(),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: _loadWeather,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceTint.withAlpha(20),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _weather != null 
                            ? '${_weather!.temperature.round()}°'
                            : '--°',
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          fontSize: 72,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _weather?.condition ?? 'Loading...',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceTint.withAlpha(20),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Weather Forecast',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 100,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _forecast.length,
                          itemBuilder: (context, index) {
                            final forecast = _forecast[index];
                            final date = forecast.date;
                            return Padding(
                              padding: const EdgeInsets.only(right: 16),
                              child: Column(
                                children: [
                                  Text(
                                    date != null 
                                        ? _getDayName(date)
                                        : '',
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                  Text(
                                    date != null 
                                        ? '${date.hour}:00'
                                        : '',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${forecast.temperature.round()}°',
                                    style: Theme.of(context).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    forecast.condition,
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'Powered by Open-Meteo',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}