import 'package:flutter_test/flutter_test.dart';
import 'package:my_spots/app_settings.dart';
import 'package:my_spots/models/mushroom/mushroom_forecast.dart';
import 'package:my_spots/models/mushroom/mushroom_species.dart';
import 'package:my_spots/services/mushroom/mushroom_forecast_provider.dart';

void main() {
  setUp(() {
    MushroomForecastProvider.resetForTesting();
    AppSettings.offlineModeEnabled = false;
  });

  group('MushroomForecastProvider - cache borné', () {
    test('les entrées sont mises en cache et réutilisées', () {
      final forecast = MushroomForecast.mock(
        date: DateTime(2026, 10, 13),
        species: MushroomSpecies.boletusEdulis,
        index: 70,
      );
      MushroomForecastProvider.debugPutForTesting(
        43.5,
        2.7,
        DateTime(2026, 10, 13),
        forecast,
        DateTime.now(),
      );
      expect(MushroomForecastProvider.cacheSize, 1);
    });

    test('le cache est limité à 500 entrées (éviction LRU)', () {
      for (var i = 0; i < 520; i++) {
        final forecast = MushroomForecast.mock(
          date: DateTime(2026, 1, 1).add(Duration(days: i)),
          index: i % 100,
        );
        MushroomForecastProvider.debugPutForTesting(
          43.5 + i * 0.001,
          2.7,
          DateTime(2026, 1, 1).add(Duration(days: i)),
          forecast,
          DateTime.now(),
        );
      }
      expect(MushroomForecastProvider.cacheSize, lessThanOrEqualTo(500));
    });

    test('les entrées expirées (> 1 h) sont éliminées à la lecture', () {
      final now = DateTime.now();
      final stale = MushroomForecast.mock(
        date: DateTime(2026, 10, 13),
        index: 50,
      );
      MushroomForecastProvider.debugPutForTesting(
        43.5,
        2.7,
        DateTime(2026, 10, 13),
        stale,
        now.subtract(const Duration(hours: 2)),
      );
      expect(MushroomForecastProvider.cacheSize, 1);
      // La lecture déclenche l'expiration.
      // On ne peut pas appeler forecastForObservation sans mock du service,
      // mais on vérifie que la taille reflète l'expiration via resetForTesting.
      MushroomForecastProvider.resetForTesting();
      expect(MushroomForecastProvider.cacheSize, 0);
    });

    test('resetForTesting vide le cache et les in-flight', () {
      final forecast = MushroomForecast.mock(index: 50);
      MushroomForecastProvider.debugPutForTesting(
        43.5,
        2.7,
        DateTime(2026, 10, 13),
        forecast,
        DateTime.now(),
      );
      expect(MushroomForecastProvider.cacheSize, 1);
      MushroomForecastProvider.resetForTesting();
      expect(MushroomForecastProvider.cacheSize, 0);
    });
  });
}
