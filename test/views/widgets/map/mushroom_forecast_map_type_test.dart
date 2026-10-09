import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:my_spots/app_settings.dart';
import 'package:my_spots/models/waypoint.dart';
import 'package:my_spots/views/map_screen.dart';
import 'package:my_spots/views/widgets/map/map_context_menu.dart';
import 'package:my_spots/views/widgets/map/selected_waypoint_panel.dart';

void main() {
  tearDown(() => AppSettings.mapType = MapType.marine);

  testWidgets('menu marin garde Ajouter waypoint et masque la prévision', (
    tester,
  ) async {
    AppSettings.mapType = MapType.marine;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showMapContextMenu(
                context,
                const LatLng(43.5, 2.7),
                _callbacks(),
              ),
              child: const Text('Ouvrir le menu'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Ouvrir le menu'));
    await tester.pumpAndSettle();

    expect(find.text('Ajouter un waypoint ici'), findsOneWidget);
    expect(find.text('Prévision cèpe ici'), findsNothing);
  });

  testWidgets('panneau marin garde Noter une observation seulement', (
    tester,
  ) async {
    AppSettings.mapType = MapType.marine;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SelectedWaypointPanel(
            waypoint: Waypoint(
              name: 'Cèpes',
              latitude: 43.5,
              longitude: 2.7,
              createdAt: DateTime(2026),
              category: WaypointCategory.mushrooms,
            ),
            currentPosition: null,
            onCenterOnTarget: () {},
            onEditWaypoint: (_) async {},
            onStartNavigation: () {},
            onShowMushroomForecast: () {},
            onClose: () {},
          ),
        ),
      ),
    );

    expect(find.text('Prévision cèpe ici'), findsNothing);
    expect(find.text('Noter une observation'), findsOneWidget);
  });

  testWidgets('garde-fou map screen ignore la prévision en mode marin', (
    tester,
  ) async {
    AppSettings.mapType = MapType.marine;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showMushroomForecastIfAllowed(
                context,
                const LatLng(43.5, 2.7),
              ),
              child: const Text('Demander la prévision'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Demander la prévision'));
    await tester.pumpAndSettle();

    expect(find.text('Prévision cèpe de Bordeaux'), findsNothing);
  });
}

MapContextMenuCallbacks _callbacks() => MapContextMenuCallbacks(
  onAddWaypoint: (_) async {},
  onOpenOfflineZone: (_) async {},
  onShowOfflineModeBlockingDialog: (_) async {},
  onStartDistanceMeasurement: (_) {},
  onShowMushroomForecast: (_) async {},
);
