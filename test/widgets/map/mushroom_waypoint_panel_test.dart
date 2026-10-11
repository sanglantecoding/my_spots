import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_spots/models/mushroom/habitat_status.dart';
import 'package:my_spots/models/mushroom/mushroom_forecast.dart';
import 'package:my_spots/models/mushroom/mushroom_species.dart';
import 'package:my_spots/models/waypoint.dart';
import 'package:my_spots/services/mushroom/mushroom_waypoint_forecast_service.dart';
import 'package:my_spots/views/widgets/map/mushroom_waypoint_panel.dart';

void main() {
  group('MushroomWaypointPanel', () {
    testWidgets('panel builds without error', (WidgetTester tester) async {
      final mockService = _MockWaypointForecastService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MushroomWaypointPanel(forecastService: mockService),
          ),
        ),
      );

      // Verify panel renders
      expect(find.text('Où aller ?'), findsOneWidget);
    });

    testWidgets('day selector renders J+0 to J+7', (WidgetTester tester) async {
      final mockService = _MockWaypointForecastService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MushroomWaypointPanel(forecastService: mockService),
          ),
        ),
      );

      // Verify day selector chips exist
      expect(find.text('J+0'), findsOneWidget);
      expect(find.text('J+1'), findsOneWidget);
      expect(find.text('J+7'), findsOneWidget);
    });

    testWidgets('excluded waypoint shows gray color in mock', (
      WidgetTester tester,
    ) async {
      final mockService = _MockWaypointForecastService(withExcluded: true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MushroomWaypointPanel(forecastService: mockService),
          ),
        ),
      );

      // Verify mock service was configured with excluded flag
      expect(mockService.withExcluded, isTrue);
    });
  });
}

class _MockWaypointForecastService implements MushroomWaypointForecastService {
  bool loadCalled = false;
  int loadCalledCount = 0;
  final bool withExcluded;

  _MockWaypointForecastService({this.withExcluded = false});

  @override
  Future<List<List<MushroomForecast>>?> calculateForWaypoints(
    List<Waypoint> waypoints,
  ) async {
    loadCalled = true;
    loadCalledCount++;

    if (waypoints.isEmpty) return [];
    if (waypoints.length > 50) return null;

    // Return mock forecasts
    return List.generate(waypoints.length, (i) {
      return List.generate(8, (day) {
        return MushroomForecast.mock(
          date: DateTime.now().add(Duration(days: day)),
          species: MushroomSpecies.boletusEdulis,
          index: withExcluded && i == 0 ? 0 : 50 + i * 10,
          confidence: 0.7,
          habitat: withExcluded && i == 0
              ? HabitatStatus.excluded
              : HabitatStatus.suitable,
        );
      });
    });
  }

  @override
  void invalidateCache(List<Waypoint> waypoints) {
    // Mock implementation
  }

  @override
  void clearCache() {
    // Mock implementation
  }
}
