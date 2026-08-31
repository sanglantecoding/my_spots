import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_spots/models/waypoint.dart';

void main() {
  group('WaypointStore - Persistence Tests', () {
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SharedPreferences.getInstance();
      WaypointStore.waypoints.clear();
    });

    group('load - Chargement depuis SharedPreferences', () {
      test('Charge une liste de waypoints valide', () async {
        final waypointJson = jsonEncode([
          {
            'name': 'Spot de peche 1',
            'latitude': 43.5,
            'longitude': 3.9,
            'createdAt': '2024-01-15T10:30:00.000Z',
            'colorHex': 'FFFFEB3B',
            'category': 'fishing',
            'gpsStatus': 'Vert',
          },
        ]);

        SharedPreferences.setMockInitialValues({'waypoints': waypointJson});
        await WaypointStore.load();

        expect(WaypointStore.waypoints.length, 1);
        expect(WaypointStore.waypoints[0].name, 'Spot de peche 1');
        expect(WaypointStore.waypoints[0].latitude, 43.5);
        expect(WaypointStore.waypoints[0].category, WaypointCategory.fishing);
      });

      test('Charge liste vide si aucune donnee', () async {
        SharedPreferences.setMockInitialValues({});
        await WaypointStore.load();

        expect(WaypointStore.waypoints.isEmpty, true);
      });

      test('Ignore les donnees JSON invalides', () async {
        SharedPreferences.setMockInitialValues({'waypoints': 'not valid json'});
        await WaypointStore.load();

        expect(WaypointStore.waypoints.isEmpty, true);
      });

      test('Ignore si waypoints n est pas une liste', () async {
        SharedPreferences.setMockInitialValues({
          'waypoints': '{"name": "not a list"}',
        });
        await WaypointStore.load();

        expect(WaypointStore.waypoints.isEmpty, true);
      });

      test('Ignore un waypoint corrompu parmi des valides', () async {
        final waypointJson = jsonEncode([
          {'name': 'Valide', 'latitude': 43.5, 'longitude': 3.9,
            'createdAt': '2024-01-15T10:30:00.000Z'},
          'invalid waypoint entry',
          {'name': 'Autre valide', 'latitude': 44.0, 'longitude': 4.0,
            'createdAt': '2024-02-20T14:00:00.000Z'},
        ]);

        SharedPreferences.setMockInitialValues({'waypoints': waypointJson});
        await WaypointStore.load();

        expect(WaypointStore.waypoints.length, 2);
        expect(WaypointStore.waypoints[0].name, 'Valide');
      });

      test('Charge avec valeurs par defaut pour champs manquants', () async {
        final waypointJson = jsonEncode([
          {'name': 'Minimal', 'latitude': 43.5, 'longitude': 3.9,
            'createdAt': '2024-01-15T10:30:00.000Z'},
        ]);

        SharedPreferences.setMockInitialValues({'waypoints': waypointJson});
        await WaypointStore.load();

        final wp = WaypointStore.waypoints[0];
        expect(wp.colorHex, 'FFFFEB3B');
        expect(wp.category, WaypointCategory.fishing);
        expect(wp.gpsStatus, 'Inconnu');
      });
    });

    group('save - Sauvegarde vers SharedPreferences', () {
      test('Sauvegarde une liste de waypoints', () async {
        WaypointStore.waypoints.add(Waypoint(
          name: 'Test Save',
          latitude: 45.0,
          longitude: 5.0,
          createdAt: DateTime(2024, 3, 1),
        ));

        await WaypointStore.save();

        final prefs = await SharedPreferences.getInstance();
        final saved = prefs.getString('waypoints');

        expect(saved, isNotNull);

        final decoded = jsonDecode(saved!) as List;
        expect(decoded.length, 1);
        expect(decoded[0]['name'], 'Test Save');
        expect(decoded[0]['latitude'], 45.0);
      });

      test('Sauvegarde plusieurs waypoints', () async {
        WaypointStore.waypoints.addAll([
          Waypoint(name: 'WP1', latitude: 43.0, longitude: 3.0,
              createdAt: DateTime(2024, 1, 1),
              category: WaypointCategory.fishing),
          Waypoint(name: 'WP2', latitude: 44.0, longitude: 4.0,
              createdAt: DateTime(2024, 2, 2),
              category: WaypointCategory.mushrooms),
          Waypoint(name: 'WP3', latitude: 45.0, longitude: 5.0,
              createdAt: DateTime(2024, 3, 3),
              category: WaypointCategory.other),
        ]);

        await WaypointStore.save();

        final prefs = await SharedPreferences.getInstance();
        final saved = prefs.getString('waypoints');
        final decoded = jsonDecode(saved!) as List;

        expect(decoded.length, 3);
        expect(decoded[0]['category'], 'fishing');
        expect(decoded[1]['category'], 'mushrooms');
        expect(decoded[2]['category'], 'other');
      });

      test('Sauvegarde liste vide', () async {
        WaypointStore.waypoints.clear();
        await WaypointStore.save();

        final prefs = await SharedPreferences.getInstance();
        final saved = prefs.getString('waypoints');
        final decoded = jsonDecode(saved!) as List;

        expect(decoded.isEmpty, true);
      });
    });

    group('Cycle de vie add/remove', () {
      test('Ajout d un waypoint', () {
        WaypointStore.waypoints.add(Waypoint(
          name: 'New Spot',
          latitude: 43.5,
          longitude: 3.9,
          createdAt: DateTime.now(),
        ));

        expect(WaypointStore.waypoints.length, 1);
        expect(WaypointStore.waypoints[0].name, 'New Spot');
      });

      test('Suppression d un waypoint', () {
        final wp1 = Waypoint(name: 'To Keep', latitude: 43.5,
            longitude: 3.9, createdAt: DateTime.now());
        final wp2 = Waypoint(name: 'To Remove', latitude: 44.0,
            longitude: 4.0, createdAt: DateTime.now());

        WaypointStore.waypoints.addAll([wp1, wp2]);
        WaypointStore.waypoints.remove(wp2);

        expect(WaypointStore.waypoints.length, 1);
        expect(WaypointStore.waypoints[0].name, 'To Keep');
      });

      test('Vider la liste', () {
        WaypointStore.waypoints.addAll([
          Waypoint(name: 'WP1', latitude: 43.0, longitude: 3.0,
              createdAt: DateTime.now()),
          Waypoint(name: 'WP2', latitude: 44.0, longitude: 4.0,
              createdAt: DateTime.now()),
        ]);

        WaypointStore.waypoints.clear();

        expect(WaypointStore.waypoints.isEmpty, true);
      });
    });

    group('Round-trip save/load', () {
      test('Sauvegarde puis chargement retourne memes donnees', () async {
        final original = [
          Waypoint(name: 'Spot A', latitude: 43.5, longitude: 3.9,
              createdAt: DateTime(2024, 1, 1)),
          Waypoint(name: 'Spot B', latitude: 44.0, longitude: 4.0,
              createdAt: DateTime(2024, 2, 2),
              category: WaypointCategory.mushrooms),
        ];

        WaypointStore.waypoints.addAll(original);
        await WaypointStore.save();

        WaypointStore.waypoints.clear();
        await WaypointStore.load();

        expect(WaypointStore.waypoints.length, 2);
        expect(WaypointStore.waypoints[0].name, 'Spot A');
        expect(WaypointStore.waypoints[1].name, 'Spot B');
        expect(WaypointStore.waypoints[1].category, WaypointCategory.mushrooms);
      });
    });
  });
}
