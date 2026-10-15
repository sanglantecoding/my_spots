import 'package:flutter_test/flutter_test.dart';
import 'package:my_spots/models/mushroom/weather_day.dart';

void main() {
  group('WeatherDay', () {
    test('creates instance with correct values', () {
      final date = DateTime(2024, 10, 5);
      final day = WeatherDay(
        date: date,
        temperatureMin: 10.0,
        temperatureMax: 20.0,
        temperatureMean: 15.0,
        precipitation: 5.0,
        humidity: 70.0,
      );

      expect(day.date, date);
      expect(day.kind, WeatherDataKind.historical);
      expect(day.temperatureMin, 10.0);
      expect(day.temperatureMax, 20.0);
      expect(day.temperatureMean, 15.0);
      expect(day.precipitation, 5.0);
      expect(day.humidity, 70.0);
      expect(day.et0, isNull);
      expect(day.windSpeed, isNull);
      expect(day.windGust, isNull);
      expect(day.solarRadiation, isNull);
    });

    test('records historical provenance by default', () {
      final day = WeatherDay.mock();

      expect(day.kind, WeatherDataKind.historical);
    });

    test('records forecast provenance when specified', () {
      final day = WeatherDay.mock(kind: WeatherDataKind.forecast);

      expect(day.kind, WeatherDataKind.forecast);
    });

    test('mock leaves measurements absent unless supplied', () {
      final day = WeatherDay.mock();

      expect(day.temperatureMin, isNull);
      expect(day.temperatureMax, isNull);
      expect(day.temperatureMean, isNull);
      expect(day.precipitation, isNull);
      expect(day.humidity, isNull);
    });
  });
}
