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

    test('cumulativePrecipitation sums precipitation', () {
      final days = [
        WeatherDay.mock(precip: 10.0),
        WeatherDay.mock(precip: 5.0),
        WeatherDay.mock(precip: 3.0),
      ];

      expect(WeatherDay.cumulativePrecipitation(days).value, 18.0);
    });

    test('cumulativePrecipitation returns 0 for empty list', () {
      final aggregate = WeatherDay.cumulativePrecipitation([]);

      expect(aggregate.value, isNull);
      expect(aggregate.windowLength, 0);
      expect(aggregate.observedCount, 0);
      expect(aggregate.isEmpty, isTrue);
      expect(aggregate.isComplete, isFalse);
      expect(aggregate.isPartial, isFalse);
    });

    test('meanTemperature calculates average', () {
      final days = [
        WeatherDay.mock(tempMean: 10.0),
        WeatherDay.mock(tempMean: 20.0),
        WeatherDay.mock(tempMean: 30.0),
      ];

      expect(WeatherDay.meanTemperature(days).value, 20.0);
    });

    test('meanTemperature returns 0 for empty list', () {
      expect(WeatherDay.meanTemperature([]).value, isNull);
    });
  });

  group('WeatherAggregate coverage', () {
    test('marks a fully observed precipitation window as complete', () {
      final days = [
        WeatherDay.mock(precip: 10.0),
        WeatherDay.mock(precip: 5.0),
        WeatherDay.mock(precip: 3.0),
      ];

      final aggregate = WeatherDay.cumulativePrecipitation(days);

      expect(aggregate.value, 18.0);
      expect(aggregate.windowLength, 3);
      expect(aggregate.observedCount, 3);
      expect(aggregate.isComplete, isTrue);
      expect(aggregate.isPartial, isFalse);
      expect(aggregate.isEmpty, isFalse);
    });

    test('marks a fully observed temperature window as complete', () {
      final days = [
        WeatherDay.mock(tempMean: 10.0),
        WeatherDay.mock(tempMean: 20.0),
      ];

      final aggregate = WeatherDay.meanTemperature(days);

      expect(aggregate.value, 15.0);
      expect(aggregate.isComplete, isTrue);
      expect(aggregate.isPartial, isFalse);
    });

    test('marks a precipitation window with missing values as partial', () {
      final days = [
        WeatherDay.mock(precip: 10.0),
        WeatherDay.mock(),
        WeatherDay.mock(precip: 4.0),
      ];

      final aggregate = WeatherDay.cumulativePrecipitation(days);

      expect(aggregate.value, 14.0);
      expect(aggregate.windowLength, 3);
      expect(aggregate.observedCount, 2);
      expect(aggregate.isComplete, isFalse);
      expect(aggregate.isPartial, isTrue);
      expect(aggregate.isEmpty, isFalse);
    });

    test('marks a temperature window with missing values as partial', () {
      final days = [
        WeatherDay.mock(tempMean: 10.0),
        WeatherDay.mock(),
        WeatherDay.mock(tempMean: 20.0),
      ];

      final aggregate = WeatherDay.meanTemperature(days);

      expect(aggregate.value, 15.0);
      expect(aggregate.windowLength, 3);
      expect(aggregate.observedCount, 2);
      expect(aggregate.isComplete, isFalse);
      expect(aggregate.isPartial, isTrue);
    });

    test('does not invent values when every measurement is missing', () {
      final days = [WeatherDay.mock(), WeatherDay.mock()];

      final precip = WeatherDay.cumulativePrecipitation(days);
      final temperature = WeatherDay.meanTemperature(days);

      expect(precip.value, isNull);
      expect(precip.windowLength, 2);
      expect(precip.observedCount, 0);
      expect(precip.isEmpty, isTrue);
      expect(precip.isComplete, isFalse);
      expect(precip.isPartial, isFalse);

      expect(temperature.value, isNull);
      expect(temperature.isEmpty, isTrue);
      expect(temperature.isComplete, isFalse);
    });
  });
}
