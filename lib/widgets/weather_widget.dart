import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:weather_icons/weather_icons.dart';
import 'package:animations/animations.dart'; // Import the new package
import '../models/weather_model.dart';
import '../services/weather_service.dart';

class WeatherWidget extends StatefulWidget {
  const WeatherWidget({super.key});

  @override
  State<WeatherWidget> createState() => _WeatherWidgetState();
}

class _WeatherWidgetState extends State<WeatherWidget> {
  bool _isExpanded = false;
  final WeatherService _weatherService = WeatherService();
  Weather? _weather;
  Timer? _timer;

  final List<Shadow> _textShadows = [
    Shadow(
      blurRadius: 8.0,
      color: Colors.black.withValues(alpha: 0.3),
      offset: const Offset(0, 2),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fetchWeather();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchWeather() async {
    try {
      String city = await _weatherService.getCity();
      var weatherData = await _weatherService.fetchWeather(city);
      if (mounted) {
        setState(() {
          _weather = Weather.fromJson(weatherData);
        });
      }
    } catch (e) {
      print('Failed to fetch weather: $e');
    }
  }

  List<Color> _getGradientColors() {
    if (_weather == null) return [Colors.grey.shade800, Colors.grey.shade900];
    String condition = _weather!.weatherCondition.toLowerCase();

    if (condition.contains('clear')) return [const Color(0xff4a90e2), const Color(0xff87ceeb)];
    if (condition.contains('cloudy')) return [const Color(0xff607d8b), const Color(0xff90a4ae)];
    if (condition.contains('rain') || condition.contains('drizzle')) return [const Color(0xff424f78), const Color(0xff7487a3)];
    if (condition.contains('thunderstorm')) return [const Color(0xff2c3e50), const Color(0xff465a75)];
    if (condition.contains('snow')) return [const Color(0xffa3c2d6), const Color(0xffd0e0eb)];
    if (condition.contains('fog')) return [const Color(0xff757f9a), const Color(0xffd7dde8)];

    return [Colors.grey.shade800, Colors.grey.shade900];
  }

  IconData _getWeatherIcon() {
    if (_weather == null) return WeatherIcons.na;
    String condition = _weather!.weatherCondition.toLowerCase();

    if (condition.contains('thunderstorm')) return WeatherIcons.thunderstorm;
    if (condition.contains('drizzle')) return WeatherIcons.sprinkle;
    if (condition.contains('rain')) return WeatherIcons.rain;
    if (condition.contains('snow')) return WeatherIcons.snow;
    if (condition.contains('fog')) return WeatherIcons.fog;
    if (condition.contains('clear')) return WeatherIcons.day_sunny;
    if (condition.contains('cloudy')) return WeatherIcons.cloudy;

    return WeatherIcons.day_sunny;
  }

  @override
  Widget build(BuildContext context) {
    final BoxDecoration targetDecoration = BoxDecoration(
      gradient: LinearGradient(
        colors: _getGradientColors(),
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.25),
          blurRadius: 15,
          spreadRadius: 0,
          offset: const Offset(0, 5),
        ),
      ],
    );

    return GestureDetector(
      onTap: () {
        setState(() {
          _isExpanded = !_isExpanded;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        width: double.infinity,
        padding: const EdgeInsets.all(20.0),
        decoration: targetDecoration,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildUnexpandedView(),
            _buildExpandedSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildUnexpandedView() {
    final now = DateTime.now();
    // Use 24-hour format for easier digit splitting, then convert hour for display
    final hour24 = int.parse(DateFormat('HH').format(now));
    final hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
    final hourString = hour12.toString().padLeft(2, ' '); // Pad with space for alignment
    final minuteString = DateFormat('mm').format(now);
    final secondString = DateFormat('ss').format(now);
    final ampmString = DateFormat('a').format(now);

    final timeTextStyle = GoogleFonts.inter(
      color: Colors.white,
      fontSize: 32,
      fontWeight: FontWeight.bold,
      fontFeatures: [const FontFeature.tabularFigures()], // Keeps numbers aligned
      shadows: _textShadows,
    );
    final ampmTextStyle = timeTextStyle.copyWith(fontSize: 20, fontWeight: FontWeight.w500);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _AnimatedDigit(value: hourString[0], textStyle: timeTextStyle),
                _AnimatedDigit(value: hourString[1], textStyle: timeTextStyle),
                Text(":", style: timeTextStyle.copyWith(fontWeight: FontWeight.w300)),
                _AnimatedDigit(value: minuteString[0], textStyle: timeTextStyle),
                _AnimatedDigit(value: minuteString[1], textStyle: timeTextStyle),
                Text(":", style: timeTextStyle.copyWith(fontWeight: FontWeight.w300)),
                _AnimatedDigit(value: secondString[0], textStyle: timeTextStyle),
                _AnimatedDigit(value: secondString[1], textStyle: timeTextStyle),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: _AnimatedDigit(value: ampmString, textStyle: ampmTextStyle),
                ),
              ],
            ),
            Text(
              DateFormat('EEEE, d MMMM').format(now),
              style: GoogleFonts.inter(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _weather?.cityName ?? 'Loading...',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        BoxedIcon(
          _getWeatherIcon(),
          size: 36,
          color: Colors.white.withValues(alpha: 0.9),
        ),
      ],
    );
  }

  Widget _buildExpandedSection() {
    return AnimatedCrossFade(
      firstChild: Container(),
      secondChild: Column(
        children: [
          const SizedBox(height: 24),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.5),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: _weather == null
                ? const SizedBox(key: ValueKey('loader'))
                : RichText(
              key: const ValueKey('temp'),
              text: TextSpan(
                style: GoogleFonts.inter(
                  color: Colors.white,
                  shadows: _textShadows,
                ),
                children: [
                  TextSpan(
                    text: '${_weather?.temperature.round()}',
                    style: const TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const TextSpan(
                    text: '°C',
                    style: TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.w200,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _weather?.weatherCondition ?? '',
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 18,
              fontWeight: FontWeight.w300,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "7-day forecast coming soon!",
            style: GoogleFonts.inter(color: Colors.white70),
          ),
        ],
      ),
      crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
      duration: const Duration(milliseconds: 400),
    );
  }
}

/// A widget that animates a single digit or character using a vertical axis transition.
class _AnimatedDigit extends StatelessWidget {
  const _AnimatedDigit({
    required this.value,
    required this.textStyle,
  });

  final String value;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    return PageTransitionSwitcher(
      duration: const Duration(milliseconds: 450),
      transitionBuilder: (
          Widget child,
          Animation<double> primaryAnimation,
          Animation<double> secondaryAnimation,
          ) {
        return SharedAxisTransition(
          animation: primaryAnimation,
          secondaryAnimation: secondaryAnimation,
          transitionType: SharedAxisTransitionType.vertical,
          fillColor: Colors.transparent,
          child: child,
        );
      },
      child: Text(
        value,
        key: ValueKey<String>(value), // Essential for the transition to trigger
        style: textStyle,
      ),
    );
  }
}