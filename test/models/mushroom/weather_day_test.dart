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

    test('mock creates instance with default values', () {
      final day = WeatherDay.mock();

      expect(day.temperatureMin, 15.0);
      expect(day.temperatureMax, 25.0);
      expect(day.temperatureMean, 20.0);
      expect(day.precipitation, 5.0);
      expect(day.humidity, 70.0);
    });

    test('cumulativePrecipitation sums precipitation', () {
      final days = [
        WeatherDay.mock(precip: 10.0),
        WeatherDay.mock(precip: 5.0),
        WeatherDay.mock(precip: 3.0),
      ];

      expect(WeatherDay.cumulativePrecipitation(days), 18.0);
    });

    test('cumulativePrecipitation returns 0 for empty list', () {
      expect(WeatherDay.cumulativePrecipitation([]), 0.0);
    });

    test('meanTemperature calculates average', () {
      final days = [
        WeatherDay.mock(tempMean: 10.0),
        WeatherDay.mock(tempMean: 20.0),
        WeatherDay.mock(tempMean: 30.0),
      ];

      expect(WeatherDay.meanTemperature(days), 20.0);
    });

    test('meanTemperature returns 0 for empty list', () {
      expect(WeatherDay.meanTemperature([]), 0.0);
    });
  });
}
