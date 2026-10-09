import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:my_spots/models/mushroom/forest_data.dart';
import 'package:my_spots/models/mushroom/mushroom_species.dart';
import 'package:my_spots/models/mushroom/soil_moisture_data.dart';
import 'package:my_spots/models/mushroom/terrain_data.dart';
import 'package:my_spots/models/mushroom/weather_day.dart';
import 'package:my_spots/services/mushroom/boletus_edulis_model.dart';
import 'package:my_spots/services/mushroom/forest_service.dart';
import 'package:my_spots/services/mushroom/mushroom_forecast_service.dart';
import 'package:my_spots/services/mushroom/terrain_service.dart';
import 'package:my_spots/services/mushroom/weather_service.dart';

class MockWeatherService implements WeatherService {
  int getHistoricalWeatherCallCount = 0;
  int getWeatherForecastCallCount = 0;
  int getSoilMoistureCallCount = 0;

  @override
  Future<List<WeatherDay>> getHistoricalWeather({
    required double lat,
    required double lng,
    required int days,
  }) async {
    getHistoricalWeatherCallCount++;
    return List.generate(
      days,
      (i) => WeatherDay.mock(
        date: DateTime.now().subtract(Duration(days: days - i)),
        precip: 5.0,
        tempMean: 18.0,
      ),
    );
  }

  @override
  Future<List<WeatherDay>> getWeatherForecast({
    required double lat,
    required double lng,
    required int days,
  }) async {
    getWeatherForecastCallCount++;
    return List.generate(
      days,
      (i) => WeatherDay.mock(
        date: DateTime.now().add(Duration(days: i)),
        kind: WeatherDataKind.forecast,
        precip: 2.0,
        tempMean: 18.0,
      ),
    );
  }

  @override
  Future<List<SoilMoistureData>> getSoilMoisture({
    required double lat,
    required double lng,
  }) async {
    getSoilMoistureCallCount++;
    return [SoilMoistureData.mock()];
  }
}

class MockTerrainService implements TerrainService {
  int getTerrainDataCallCount = 0;
  double? elevation = 400.0;

  @override
  Future<TerrainData> getTerrainData({
    required double lat,
    required double lng,
  }) async {
    getTerrainDataCallCount++;
    return TerrainData(
      latitude: lat,
      longitude: lng,
      elevation: elevation,
      slope: 12.0,
      aspect: 45.0,
    );
  }

  @override
  Future<double> getElevation({
    required double lat,
    required double lng,
  }) async {
    return elevation ?? 0.0;
  }

  @override
  Future<Map<String, TerrainData>> getTerrainBatch(
    List<LatLng> centers,
    double spacingMetres,
  ) async {
    return {};
  }
}

class MockForestService implements ForestService {
  int getForestDataCallCount = 0;

  @override
  Future<ForestData> getForestData({
    required double lat,
    required double lng,
  }) async {
    getForestDataCallCount++;
    return ForestData(
      latitude: lat,
      longitude: lng,
      isForest: true,
      forestType: 'feuillu',
      canopyClass: 'fermée',
      treeDensity: null,
      canopyCover: null,
      source: 'mock',
    );
  }

  @override
  Future<Map<String, ForestData>> getForestBatch(
    LatLngBounds bounds,
    List<LatLng> centers,
  ) async {
    return {};
  }
}

void main() {
  group('MushroomForecastService', () {
    late MushroomForecastService service;
    late MockWeatherService mockWeatherService;
    late MockTerrainService mockTerrainService;
    late MockForestService mockForestService;

    setUp(() {
      mockWeatherService = MockWeatherService();
      mockTerrainService = MockTerrainService();
      mockForestService = MockForestService();

      service = MushroomForecastService(
        weatherService: mockWeatherService,
        terrainService: mockTerrainService,
        forestService: mockForestService,
      );

      service.registerEngine(BoletusEdulisModel());
    });

    test('calculateForecast calls services once', () async {
      await service.calculateForecast(
        lat: 43.5,
        lng: 3.5,
        species: MushroomSpecies.boletusEdulis,
        targetDate: DateTime.now(),
      );

      expect(mockWeatherService.getHistoricalWeatherCallCount, 1);
      expect(mockWeatherService.getWeatherForecastCallCount, 1);
      expect(mockWeatherService.getSoilMoistureCallCount, 1);
      expect(mockTerrainService.getTerrainDataCallCount, 1);
      expect(mockForestService.getForestDataCallCount, 1);
    });

    test('calculateForecastRange does not refetch data for each day', () async {
      final start = DateTime.now();
      final forecasts = await service.calculateForecastRange(
        lat: 43.5,
        lng: 3.5,
        species: MushroomSpecies.boletusEdulis,
        startDate: start,
        days: 7,
      );

      // Services appelés une seule fois pour toute la plage J+0 à J+7
      expect(mockWeatherService.getHistoricalWeatherCallCount, 1);
      expect(mockWeatherService.getWeatherForecastCallCount, 1);
      expect(mockWeatherService.getSoilMoistureCallCount, 1);
      expect(mockTerrainService.getTerrainDataCallCount, 1);
      expect(mockForestService.getForestDataCallCount, 1);

      // days:7 = J+0 inclus → 8 prévisions générées (J+0 … J+7)
      expect(forecasts.length, 8);

      // Chaque prévision a une date différente
      final dates = forecasts.map((f) => f.date).toSet();
      expect(dates.length, 8);

      // Premier jour = J+0 = startDate
      expect(forecasts.first.date.year, start.year);
      expect(forecasts.first.date.month, start.month);
      expect(forecasts.first.date.day, start.day);
      // Dernier jour = J+7
      final j7 = start.add(const Duration(days: 7));
      expect(forecasts.last.date.year, j7.year);
      expect(forecasts.last.date.month, j7.month);
      expect(forecasts.last.date.day, j7.day);
    });

    test(
      'altitude exclue arrête les appels après le terrain et renvoie J+0..J+7',
      () async {
        mockTerrainService.elevation = 50;
        final start = DateTime(2026, 10, 8);
        final forecasts = await service.calculateForecastRange(
          lat: 43.5,
          lng: 3.5,
          species: MushroomSpecies.boletusEdulis,
          startDate: start,
          days: 7,
        );

        expect(forecasts, hasLength(8));
        expect(forecasts.first.date, start);
        expect(forecasts.last.date, start.add(const Duration(days: 7)));
        expect(forecasts.every((f) => f.index == 0), isTrue);
        expect(forecasts.every((f) => f.confidence == 1.0), isTrue);
        expect(forecasts.every((f) => f.habitat.name == 'excluded'), isTrue);
        expect(forecasts.first.habitatReason, contains('sous la limite basse'));
        expect(mockTerrainService.getTerrainDataCallCount, 1);
        expect(mockWeatherService.getHistoricalWeatherCallCount, 0);
        expect(mockWeatherService.getWeatherForecastCallCount, 0);
        expect(mockWeatherService.getSoilMoistureCallCount, 0);
        expect(mockForestService.getForestDataCallCount, 0);
      },
    );

    test(
      'calculateForecast saute météo, sol et forêt si terrain exclu',
      () async {
        mockTerrainService.elevation = 1950;
        final forecast = await service.calculateForecast(
          lat: 43.5,
          lng: 3.5,
          species: MushroomSpecies.boletusEdulis,
          targetDate: DateTime(2026, 10, 8),
        );

        expect(forecast.index, 0);
        expect(forecast.confidence, 1.0);
        expect(forecast.habitat.name, 'excluded');
        expect(
          forecast.habitatReason,
          contains('au-dessus de la limite haute'),
        );
        expect(mockTerrainService.getTerrainDataCallCount, 1);
        expect(mockWeatherService.getHistoricalWeatherCallCount, 0);
        expect(mockWeatherService.getWeatherForecastCallCount, 0);
        expect(mockWeatherService.getSoilMoistureCallCount, 0);
        expect(mockForestService.getForestDataCallCount, 0);
      },
    );

    test('altitude de 600 m conserve les appels et huit résultats', () async {
      mockTerrainService.elevation = 600;
      final start = DateTime(2026, 10, 8);
      final forecasts = await service.calculateForecastRange(
        lat: 43.5,
        lng: 3.5,
        species: MushroomSpecies.boletusEdulis,
        startDate: start,
        days: 7,
      );

      expect(forecasts, hasLength(8));
      expect(forecasts.first.date, start);
      expect(forecasts.last.date, start.add(const Duration(days: 7)));
      expect(mockWeatherService.getHistoricalWeatherCallCount, 1);
      expect(mockWeatherService.getWeatherForecastCallCount, 1);
      expect(mockWeatherService.getSoilMoistureCallCount, 1);
      expect(mockTerrainService.getTerrainDataCallCount, 1);
      expect(mockForestService.getForestDataCallCount, 1);
    });

    test('altitude inconnue ne déclenche pas la sortie anticipée', () async {
      mockTerrainService.elevation = null;
      final forecasts = await service.calculateForecastRange(
        lat: 43.5,
        lng: 3.5,
        species: MushroomSpecies.boletusEdulis,
        startDate: DateTime(2026, 10, 8),
        days: 7,
      );

      expect(forecasts, hasLength(8));
      expect(forecasts.every((f) => f.habitat.name != 'excluded'), isTrue);
      expect(mockWeatherService.getHistoricalWeatherCallCount, 1);
      expect(mockWeatherService.getWeatherForecastCallCount, 1);
      expect(mockWeatherService.getSoilMoistureCallCount, 1);
      expect(mockForestService.getForestDataCallCount, 1);
    });

    test(
      'calculateForecastRange returns forecasts with valid indices',
      () async {
        final forecasts = await service.calculateForecastRange(
          lat: 43.5,
          lng: 3.5,
          species: MushroomSpecies.boletusEdulis,
          startDate: DateTime.now(),
          days: 7,
        );

        for (final forecast in forecasts) {
          expect(forecast.index, greaterThanOrEqualTo(0));
          expect(forecast.index, lessThanOrEqualTo(100));
          expect(forecast.confidence, greaterThanOrEqualTo(0.0));
          expect(forecast.confidence, lessThanOrEqualTo(1.0));
        }
      },
    );

    test('calculateGridForecast calculates small grid', () async {
      final bounds = LatLngBounds(
        const LatLng(43.0, 3.0),
        const LatLng(43.1, 3.1),
      );

      final cells = await service.calculateGridForecast(
        bounds: bounds,
        species: MushroomSpecies.boletusEdulis,
        targetDate: DateTime.now(),
        gridSizeKm: 5.0,
      );

      // Grille générée
      expect(cells.isNotEmpty, true);

      // Chaque cellule a des bounds valides
      for (final cell in cells) {
        expect(cell.bounds, isNotNull);
        expect(cell.forecast, isNotNull);
        expect(cell.calculationDate, isNotNull);
      }
    });

    test('throws ArgumentError when engine not registered', () async {
      final serviceWithoutEngine = MushroomForecastService(
        weatherService: mockWeatherService,
        terrainService: mockTerrainService,
        forestService: mockForestService,
      );

      expect(
        () => serviceWithoutEngine.calculateForecast(
          lat: 43.5,
          lng: 3.5,
          species: MushroomSpecies.boletusEdulis,
          targetDate: DateTime.now(),
        ),
        throwsArgumentError,
      );
    });
  });
}
