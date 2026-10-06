import 'package:flutter_test/flutter_test.dart';
import 'package:my_spots/models/mushroom/mushroom_forecast.dart';
import 'package:my_spots/models/mushroom/mushroom_species.dart';

void main() {
  group('MushroomForecast', () {
    test('creates instance with correct values', () {
      final date = DateTime(2024, 10, 5);
      final forecast = MushroomForecast(
        date: date,
        species: MushroomSpecies.boletusEdulis,
        index: 75,
        confidence: 0.8,
        factors: ForecastFactors(
          waterFactor: 0.7,
          temperatureFactor: 0.6,
          dryingFactor: 0.8,
          terrainFactor: 0.5,
          forestFactor: 0.9,
        ),
      );

      expect(forecast.date, date);
      expect(forecast.species, MushroomSpecies.boletusEdulis);
      expect(forecast.index, 75);
      expect(forecast.confidence, 0.8);
      expect(forecast.factors.waterFactor, 0.7);
    });

    test('mock creates instance with default values', () {
      final forecast = MushroomForecast.mock();

      expect(forecast.species, MushroomSpecies.boletusEdulis);
      expect(forecast.index, 50);
      expect(forecast.confidence, 0.7);
    });
  });

  group('ForecastFactors', () {
    test('creates instance with correct values', () {
      final factors = ForecastFactors(
        waterFactor: 0.7,
        temperatureFactor: 0.6,
        dryingFactor: 0.8,
        terrainFactor: 0.5,
        forestFactor: 0.9,
      );

      expect(factors.waterFactor, 0.7);
      expect(factors.temperatureFactor, 0.6);
      expect(factors.dryingFactor, 0.8);
      expect(factors.terrainFactor, 0.5);
      expect(factors.forestFactor, 0.9);
    });

    test('mock creates instance with default values', () {
      final factors = ForecastFactors.mock();

      expect(factors.waterFactor, 0.5);
      expect(factors.temperatureFactor, 0.5);
      expect(factors.dryingFactor, 0.5);
      expect(factors.terrainFactor, 0.5);
      expect(factors.forestFactor, 0.5);
    });
  });
}
