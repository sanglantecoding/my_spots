import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_spots/views/map_screen.dart';

void main() {
  group('MapScreen Widget Tests', () {
    testWidgets('MapScreen renders without crashing', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: MapScreen()));

      // Vérifie que le Scaffold est rendu
      expect(find.byType(Scaffold), findsOneWidget);

      // Vérifie que l'AppBar est présente
      expect(find.byType(AppBar), findsOneWidget);

      // Vérifie le titre de l'AppBar
      expect(find.text('CARTE'), findsOneWidget);
    });

    testWidgets('MapScreen with centerOn parameter', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: MapScreen(centerOn: null)),
      );

      expect(find.byType(MapScreen), findsOneWidget);
    });

    testWidgets('MapScreen with triggerZoneCreation parameter', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: MapScreen(triggerZoneCreation: false)),
      );

      expect(find.byType(MapScreen), findsOneWidget);
    });

    testWidgets('MapScreen shows loading indicator initially', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: MapScreen()));

      // L'indicateur de chargement devrait être visible initialement
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Chargement de la carte...'), findsOneWidget);
    });

    testWidgets('MapScreen has back button in AppBar', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: MapScreen()));

      // Vérifie le bouton de retour
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('MapScreen has settings button in AppBar', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: MapScreen()));

      // Vérifie le bouton settings
      expect(find.byIcon(Icons.settings), findsOneWidget);
    });
  });
}
