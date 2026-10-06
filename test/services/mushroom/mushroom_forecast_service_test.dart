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

  @override
  Future<TerrainData> getTerrainData({
    required double lat,
    required double lng,
  }) async {
    getTerrainDataCallCount++;
    return TerrainData.mock(elevation: 400.0, slope: 12.0, aspect: 45.0);
  }

  @override
  Future<double> getElevation({
    required double lat,
    required double lng,
  }) async {
    return 400.0;
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
    return ForestData.mock(
      isForest: true,
      forestType: 'feuillu',
      treeDensity: 60.0,
    );
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
      final forecasts = await service.calculateForecastRange(
        lat: 43.5,
        lng: 3.5,
        species: MushroomSpecies.boletusEdulis,
        startDate: DateTime.now(),
        days: 7,
      );

      // Services appelés une seule fois pour toute la plage J+0 à J+7
      expect(mockWeatherService.getHistoricalWeatherCallCount, 1);
      expect(mockWeatherService.getWeatherForecastCallCount, 1);
      expect(mockWeatherService.getSoilMoistureCallCount, 1);
      expect(mockTerrainService.getTerrainDataCallCount, 1);
      expect(mockForestService.getForestDataCallCount, 1);

      // 7 prévisions générées
      expect(forecasts.length, 7);

      // Chaque prévision a une date différente
      final dates = forecasts.map((f) => f.date).toSet();
      expect(dates.length, 7);
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
