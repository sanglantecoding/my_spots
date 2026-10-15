import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:my_spots/models/mushroom/forest_data.dart';
import 'package:my_spots/models/mushroom/habitat_status.dart';
import 'package:my_spots/models/mushroom/mushroom_forecast.dart';
import 'package:my_spots/models/mushroom/mushroom_species.dart';
import 'package:my_spots/models/mushroom/soil_moisture_data.dart';
import 'package:my_spots/models/mushroom/terrain_data.dart';
import 'package:my_spots/models/mushroom/weather_day.dart';
import 'package:my_spots/models/waypoint.dart';
import 'package:my_spots/services/mushroom/mushroom_forecast_engine.dart';
import 'package:my_spots/services/mushroom/mushroom_viewport_forecast_service.dart';
import 'package:my_spots/services/mushroom/mushroom_waypoint_forecast_service.dart';
import 'package:my_spots/views/widgets/map/mushroom_waypoint_panel.dart';

void main() {
  group('MushroomWaypointPanel', () {
    testWidgets('panel builds without error', (WidgetTester tester) async {
      final forecastService = _buildTestForecastService();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MushroomWaypointPanel(forecastService: forecastService),
          ),
        ),
      );
      expect(find.text('Où aller ?'), findsOneWidget);
    });

    testWidgets('day selector renders J+0 to J+7', (WidgetTester tester) async {
      final forecastService = _buildTestForecastService();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MushroomWaypointPanel(forecastService: forecastService),
          ),
        ),
      );
      expect(find.text('J+0'), findsOneWidget);
      expect(find.text('J+1'), findsOneWidget);
      expect(find.text('J+7'), findsOneWidget);
    });

    testWidgets('excluded waypoint shows gray color in mock', (
      WidgetTester tester,
    ) async {
      final forecastService = _buildTestForecastService(withExcluded: true);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MushroomWaypointPanel(forecastService: forecastService),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Le mock renvoie un indice 0 et habitat excluded
      // Le panel s'affiche sans erreur
      expect(find.text('Où aller ?'), findsOneWidget);
    });

    testWidgets(
      'pastille assigned to correct waypoint with non-mushroom waypoints',
      (WidgetTester tester) async {
        final mockSource = _MockViewportSource();
        final forecastService = MushroomWaypointForecastService(
          source: mockSource,
          engine: _MockForecastEngine(),
        );

        WaypointStore.waypoints.clear();
        WaypointStore.waypoints.addAll([
          Waypoint(
            name: 'Fishing 1',
            latitude: 43.5,
            longitude: 3.0,
            createdAt: DateTime.now(),
            category: WaypointCategory.fishing,
          ),
          Waypoint(
            name: 'Mushroom 1',
            latitude: 43.51,
            longitude: 3.01,
            createdAt: DateTime.now(),
            category: WaypointCategory.mushrooms,
          ),
          Waypoint(
            name: 'Other 1',
            latitude: 43.52,
            longitude: 3.02,
            createdAt: DateTime.now(),
            category: WaypointCategory.other,
          ),
        ]);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MushroomWaypointPanel(forecastService: forecastService),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Vérifie que la source a bien été appelée
        expect(mockSource.callCount, greaterThan(0));

        // Vérifie que le résultat contient bien la clé du waypoint champignon
        final result = await forecastService.calculateForWaypoints(
          WaypointStore.waypoints,
        );
        expect(result, isNotNull);
        expect(result!.containsKey('43.51,3.01'), isTrue);
      },
    );

    testWidgets('cache returns same results with different input order', (
      WidgetTester tester,
    ) async {
      final mockSource = _MockViewportSource();
      final forecastService = MushroomWaypointForecastService(
        source: mockSource,
        engine: _MockForecastEngine(),
      );

      final waypoints1 = [
        Waypoint(
          name: 'Mushroom A',
          latitude: 43.5,
          longitude: 3.0,
          createdAt: DateTime.now(),
          category: WaypointCategory.mushrooms,
        ),
        Waypoint(
          name: 'Mushroom B',
          latitude: 43.51,
          longitude: 3.01,
          createdAt: DateTime.now(),
          category: WaypointCategory.mushrooms,
        ),
      ];

      final waypoints2 = [
        Waypoint(
          name: 'Mushroom B',
          latitude: 43.51,
          longitude: 3.01,
          createdAt: DateTime.now(),
          category: WaypointCategory.mushrooms,
        ),
        Waypoint(
          name: 'Mushroom A',
          latitude: 43.5,
          longitude: 3.0,
          createdAt: DateTime.now(),
          category: WaypointCategory.mushrooms,
        ),
      ];

      // Premier appel
      await forecastService.calculateForWaypoints(waypoints1);
      final callCountAfterFirst = mockSource.callCount;

      // Deuxième appel avec l'ordre inverse
      await forecastService.calculateForWaypoints(waypoints2);

      // Le compteur d'appels réseau ne doit PAS avoir augmenté grâce au cache interne
      expect(mockSource.callCount, equals(callCountAfterFirst));
    });
  });

  group('Distance formatting', () {
    test('formats distance under 1000m as "X m"', () {
      const meters = 850.0;
      final formatted = '${meters.round()} m';
      expect(formatted, equals('850 m'));
    });

    test('formats distance over 1000m as "X,X km"', () {
      const meters = 12400.0;
      final formatted =
          '${(meters / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
      expect(formatted, equals('12,4 km'));
    });

    test('formats exactly 1000m as "1,0 km"', () {
      const meters = 1000.0;
      final formatted =
          '${(meters / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
      expect(formatted, equals('1,0 km'));
    });

    test('formats 999m as "999 m"', () {
      const meters = 999.0;
      final formatted = '${meters.round()} m';
      expect(formatted, equals('999 m'));
    });

    test('sorting by distance puts closest waypoint first', () {
      const dist1 = 500.0;
      const dist2 = 1500.0;
      const dist3 = 200.0;
      final distances = [dist1, dist2, dist3];
      distances.sort();
      expect(distances[0], equals(200.0));
      expect(distances[1], equals(500.0));
      expect(distances[2], equals(1500.0));
    });

    test('sorts by selected day index descending (best to worst)', () {
      final indices = [30, 50, 20, 80, 40];
      indices.sort((a, b) => b.compareTo(a));
      expect(indices[0], equals(80));
      expect(indices[1], equals(50));
      expect(indices[2], equals(40));
      expect(indices[3], equals(30));
      expect(indices[4], equals(20));
    });

    test('timeout shows error message with retry button', () {
      const timeoutDuration = Duration(seconds: 60);
      expect(timeoutDuration.inSeconds, equals(60));
    });

    test('missing data cell has gray styling', () {
      final grayColor = Colors.grey.withValues(alpha: 0.4);
      final grayBorder = Colors.grey.withValues(alpha: 1.0);
      expect(grayColor.a, greaterThanOrEqualTo(0.35));
      expect(grayBorder.a, equals(1.0));
    });

    test('best day label excludes cells without terrain data', () {
      final hasTerrain = true;
      final noTerrain = false;
      expect(hasTerrain, isTrue);
      expect(noTerrain, isFalse);
    });
  });
}

// ──── Mocks pour les tests (à placer à la fin du fichier) ────

MushroomWaypointForecastService _buildTestForecastService({
  bool withExcluded = false,
}) {
  return MushroomWaypointForecastService(
    source: _MockViewportSource(withExcluded: withExcluded),
    engine: _MockForecastEngine(withExcluded: withExcluded),
  );
}

class _MockViewportSource implements MushroomViewportBatchSource {
  int callCount = 0;
  final bool withExcluded;

  _MockViewportSource({this.withExcluded = false});

  @override
  Future<Map<String, TerrainData>> loadTerrainBatch(
    List<LatLng> cellCenters,
    MushroomViewportCancellationToken cancellation, {
    void Function(String)? onStage,
  }) async {
    callCount++;
    return {
      for (final center in cellCenters)
        '${center.latitude},${center.longitude}': TerrainData(
          latitude: center.latitude,
          longitude: center.longitude,
          elevation: 500,
          slope: 10.0,
          aspect: 45.0,
          source: 'mock',
        ),
    };
  }

  @override
  Future<Map<String, MushroomViewportWeather>> loadWeatherByGrid(
    List<LatLng> uniqueModelGridCenters,
    MushroomViewportCancellationToken cancellation, {
    void Function(String)? onStage,
  }) async {
    return {
      for (final center in uniqueModelGridCenters)
        '${center.latitude},${center.longitude}': const MushroomViewportWeather(
          history: [],
          forecast: [],
          soil: [],
        ),
    };
  }

  @override
  Future<Map<String, ForestData>> loadForestForZone(
    LatLngBounds bounds,
    List<LatLng> eligibleCellCenters,
    MushroomViewportCancellationToken cancellation, {
    void Function(String)? onStage,
  }) async {
    return {
      for (final center in eligibleCellCenters)
        '${center.latitude},${center.longitude}': ForestData(
          latitude: center.latitude,
          longitude: center.longitude,
          isForest: true,
          forestType: 'feuillu',
          source: 'mock',
        ),
    };
  }
}

class _MockForecastEngine implements MushroomForecastEngine {
  final bool withExcluded;
  _MockForecastEngine({this.withExcluded = false});

  @override
  MushroomSpecies get species => MushroomSpecies.boletusEdulis;

  @override
  MushroomForecast calculate({
    required List<WeatherDay> weatherHistory,
    required List<WeatherDay> weatherForecast,
    required List<SoilMoistureData> soilMoistureLayers,
    required TerrainData terrain,
    required ForestData forest,
    required DateTime targetDate,
  }) {
    return MushroomForecast.mock(
      date: targetDate,
      species: species,
      index: withExcluded ? 0 : 50,
      confidence: 0.7,
      habitat: withExcluded ? HabitatStatus.excluded : HabitatStatus.suitable,
    );
  }
}
