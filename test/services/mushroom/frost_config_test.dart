import 'package:flutter_test/flutter_test.dart';
import 'package:my_spots/models/mushroom/weather_day.dart';
import 'package:my_spots/services/mushroom/frost_config.dart';

void main() {
  group('FrostConfig', () {
    test('frostMultiplier: -4°C before target -> 0.3', () {
      final targetDate = DateTime.utc(2026, 10, 15);
      final weather = [
        WeatherDay(
          date: DateTime.utc(2026, 10, 14),
          temperatureMin: -4.0,
          temperatureMean: 2.0,
          temperatureMax: 8.0,
        ),
        WeatherDay(
          date: DateTime.utc(2026, 10, 13),
          temperatureMin: 0.0,
          temperatureMean: 3.0,
          temperatureMax: 7.0,
        ),
        WeatherDay(
          date: DateTime.utc(2026, 10, 12),
          temperatureMin: 2.0,
          temperatureMean: 5.0,
          temperatureMax: 10.0,
        ),
      ];
      final multiplier = FrostConfig.frostMultiplier(targetDate, weather);
      expect(multiplier, equals(FrostConfig.severeFrostMultiplier));
    });

    test('frostMultiplier: 0°C before target -> 0.6', () {
      final targetDate = DateTime.utc(2026, 10, 15);
      final weather = [
        WeatherDay(
          date: DateTime.utc(2026, 10, 14),
          temperatureMin: 0.0,
          temperatureMean: 3.0,
          temperatureMax: 7.0,
        ),
        WeatherDay(
          date: DateTime.utc(2026, 10, 13),
          temperatureMin: 2.0,
          temperatureMean: 5.0,
          temperatureMax: 10.0,
        ),
      ];
      final multiplier = FrostConfig.frostMultiplier(targetDate, weather);
      expect(multiplier, equals(FrostConfig.lightFrostMultiplier));
    });

    test('frostMultiplier: no frost -> 1.0', () {
      final targetDate = DateTime.utc(2026, 10, 15);
      final weather = [
        WeatherDay(
          date: DateTime.utc(2026, 10, 14),
          temperatureMin: 2.0,
          temperatureMean: 5.0,
          temperatureMax: 10.0,
        ),
      ];
      final multiplier = FrostConfig.frostMultiplier(targetDate, weather);
      expect(multiplier, equals(1.0));
    });

    test('hasRecentFrost: detects frost', () {
      final targetDate = DateTime.utc(2026, 10, 15);
      final weather = [
        WeatherDay(
          date: DateTime.utc(2026, 10, 14),
          temperatureMin: -1.0,
          temperatureMean: 2.0,
          temperatureMax: 8.0,
        ),
      ];
      expect(FrostConfig.hasRecentFrost(targetDate, weather), isTrue);
    });

    test('hasRecentFrost: no frost', () {
      final targetDate = DateTime.utc(2026, 10, 15);
      final weather = [
        WeatherDay(
          date: DateTime.utc(2026, 10, 14),
          temperatureMin: 2.0,
          temperatureMean: 5.0,
          temperatureMax: 10.0,
        ),
      ];
      expect(FrostConfig.hasRecentFrost(targetDate, weather), isFalse);
    });
  });
}
