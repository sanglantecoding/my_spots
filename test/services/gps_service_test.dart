import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:my_spots/models/waypoint.dart';
import 'package:my_spots/services/gps_service.dart';

void main() {
  group('GPS Service Tests - Cohérence des couleurs et textes', () {
    test('Seuils de précision GPS - Zone Excellent (0-8m)', () {
      for (double accuracy = 0.0; accuracy < 8.0; accuracy += 2.0) {
        final status = GpsService.getGpsStatus(accuracy);
        final color = GpsService.getAccuracyColor(accuracy);
        final text = GpsService.getAccuracyStatusText(accuracy);

        expect(status, GpsStatus.excellent);
        expect(color, Colors.green);
        expect(text, 'SIGNAL EXCELLENT');
      }
    });

    test('Seuils de précision GPS - Zone Correct (8-15m)', () {
      for (double accuracy = 8.0; accuracy < 15.0; accuracy += 2.0) {
        final status = GpsService.getGpsStatus(accuracy);
        final color = GpsService.getAccuracyColor(accuracy);
        final text = GpsService.getAccuracyStatusText(accuracy);

        expect(status, GpsStatus.good);
        expect(color, Colors.amber);
        expect(text, 'SIGNAL OK');
      }
    });

    test('Seuils de précision GPS - Zone Moyen (15-30m)', () {
      for (double accuracy = 15.0; accuracy < 30.0; accuracy += 5.0) {
        final status = GpsService.getGpsStatus(accuracy);
        final color = GpsService.getAccuracyColor(accuracy);
        final text = GpsService.getAccuracyStatusText(accuracy);

        expect(status, GpsStatus.medium);
        expect(color, Colors.orange);
        expect(text, 'RECHERCHE SATELLITES...');
      }
    });

    test('Seuils de précision GPS - Zone Faible (>30m)', () {
      for (double accuracy = 30.0; accuracy <= 50.0; accuracy += 5.0) {
        final status = GpsService.getGpsStatus(accuracy);
        final color = GpsService.getAccuracyColor(accuracy);
        final text = GpsService.getAccuracyStatusText(accuracy);

        expect(status, GpsStatus.poor);
        expect(color, Colors.red);
        expect(text, 'SIGNAL FAIBLE');
      }
    });

    test('Cohérence des fonctions unifiées', () {
      final testAccuracies = [5.0, 12.0, 20.0, 40.0];

      for (final accuracy in testAccuracies) {
        final status1 = GpsService.getGpsStatus(accuracy);
        final color1 = GpsService.getGpsStatusColor(status1);
        final color2 = GpsService.getAccuracyColor(accuracy);

        expect(color1, color2);

        final detailedText1 = GpsService.getGpsDetailedStatusText(status1);
        final detailedText2 = GpsService.getAccuracyDetailedText(accuracy);
        expect(detailedText1, detailedText2);
      }
    });

    test('Gestion des valeurs nulles', () {
      final color = GpsService.getAccuracyColor(null);
      final text = GpsService.getAccuracyStatusText(null);
      final detailedText = GpsService.getAccuracyDetailedText(null);

      expect(color, Colors.grey);
      expect(text, 'GPS: --');
      expect(detailedText, 'GPS: --');
    });

    test('Test des limites exactes', () {
      expect(GpsService.getGpsStatus(7.9), GpsStatus.excellent);
      expect(GpsService.getGpsStatus(8.0), GpsStatus.good);
      expect(GpsService.getGpsStatus(14.9), GpsStatus.good);
      expect(GpsService.getGpsStatus(15.0), GpsStatus.medium);
      expect(GpsService.getGpsStatus(29.9), GpsStatus.medium);
      expect(GpsService.getGpsStatus(30.0), GpsStatus.poor);
    });
  });

  group('GPS Service Tests - Calcul de distance (Haversine)', () {
    // Helper pour creer un Waypoint minimal
    Waypoint wp(double lat, double lon) => Waypoint(
          name: 'Test',
          latitude: lat,
          longitude: lon,
          createdAt: DateTime(2024, 1, 1),
        );

    test('Deux coordonnees identiques -> distance 0', () {
      final d = GpsService.calculateDistance(
        const LatLng(43.5, 3.9),
        wp(43.5, 3.9),
      );
      expect(d, 0.0);
    });

    test('Deplacement de 1 degre en latitude -> ~111 195 m', () {
      // A longitude constante (3.9), 1 degre de latitude = pi * R / 180
      // avec R = 6371000 m -> 111194.927 m (exact).
      final d = GpsService.calculateDistance(
        const LatLng(43.5, 3.9),
        wp(44.5, 3.9),
      );
      expect(d, closeTo(111194.927, 0.1));
    });

    test('Deplacement de 1 degre en longitude a l equateur -> ~111 195 m', () {
      final d = GpsService.calculateDistance(
        const LatLng(0.0, 0.0),
        wp(0.0, 1.0),
      );
      expect(d, closeTo(111194.927, 0.1));
    });

    test('Deplacement de 1 degre en longitude a 45 deg -> ~78 626 m', () {
      // Tolerance 2 m : l'ecart vient de la difference entre le calcul
      // Haversine (code) et l'approximation cos(45)*111195 (calcul theorique).
      final d = GpsService.calculateDistance(
        const LatLng(45.0, 0.0),
        wp(45.0, 1.0),
      );
      expect(d, closeTo(78626.188, 2.0));
    });

    test('Distance Paris -> Lyon -> ~392 287 m (ordre de grandeur realiste)', () {
      // Paris  : 48.8566 N, 2.3522 E
      // Lyon   : 45.7640 N, 4.8357 E
      // Distance a vol d oiseau referencee : ~392 km.
      // Tolerance 5 km : assez large pour absorber les differences entre
      // modele spherique de Haversine et valeurs de reference reelles.
      final d = GpsService.calculateDistance(
        const LatLng(48.8566, 2.3522),
        wp(45.7640, 4.8357),
      );
      expect(d, closeTo(392287.0, 5000.0));
    });

    test('Symetrie : distance(A, B) == distance(B, A)', () {
      const a = LatLng(43.5, 3.9);
      final b = wp(44.0, 4.0);

      final dAB = GpsService.calculateDistance(a, b);

      // Pour la symetrie, on recree un Waypoint equivalent a A.
      final aAsWp = Waypoint(
        name: 'A',
        latitude: a.latitude,
        longitude: a.longitude,
        createdAt: DateTime(2024, 1, 1),
      );
      final dBA = GpsService.calculateDistance(
        const LatLng(44.0, 4.0),
        aAsWp,
      );

      // Haversine est strictement symetrique.
      expect(dAB, closeTo(dBA, 1e-6));
    });

    test('Distance nulle entre LatLng et Waypoint equivalents', () {
      final d = GpsService.calculateDistance(
        const LatLng(48.8566, 2.3522),
        wp(48.8566, 2.3522),
      );
      expect(d, 0.0);
    });
  });
}
