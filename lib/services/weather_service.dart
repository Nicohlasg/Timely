import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;

class WeatherService {
  final String _apiKey = 'YOUR_API_KEY'; // Although Open-Meteo doesn't require a key
  final String _apiUrl = 'https://api.open-meteo.com/v1/forecast';

  Future<Map<String, dynamic>> fetchWeather(String city) async {
    try {
      List<Location> locations = await locationFromAddress(city);
      if (locations.isEmpty) {
        throw Exception('City not found');
      }
      Location location = locations.first;
      final response = await http.get(Uri.parse(
          '$_apiUrl?latitude=${location.latitude}&longitude=${location.longitude}&current_weather=true'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load weather data');
      }
    } catch (e) {
      throw Exception('Failed to get weather for $city: $e');
    }
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    return await Geolocator.getCurrentPosition();
  }

  Future<String> getCity() async {
    try {
      Position position = await _determinePosition();
      List<Placemark> placemarks =
      await placemarkFromCoordinates(position.latitude, position.longitude);
      Placemark place = placemarks[0];
      return place.locality ?? 'Unknown';
    } catch (e) {
      print(e);
      return "Could not get location";
    }
  }
}