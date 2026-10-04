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
        final color = GpsService.getGpsStatusColor(status);
        final text = GpsService.getGpsStatusText(status);

        expect(status, GpsStatus.excellent);
        expect(color, Colors.green);
        expect(text, 'SIGNAL EXCELLENT');
      }
    });

    test('Seuils de précision GPS - Zone Correct (8-15m)', () {
      for (double accuracy = 8.0; accuracy < 15.0; accuracy += 2.0) {
        final status = GpsService.getGpsStatus(accuracy);
        final color = GpsService.getGpsStatusColor(status);
        final text = GpsService.getGpsStatusText(status);

        expect(status, GpsStatus.good);
        expect(color, Colors.amber);
        expect(text, 'SIGNAL OK');
      }
    });

    test('Seuils de précision GPS - Zone Moyen (15-30m)', () {
      for (double accuracy = 15.0; accuracy < 30.0; accuracy += 5.0) {
        final status = GpsService.getGpsStatus(accuracy);
        final color = GpsService.getGpsStatusColor(status);
        final text = GpsService.getGpsStatusText(status);

        expect(status, GpsStatus.medium);
        expect(color, Colors.orange);
        expect(text, 'RECHERCHE SATELLITES...');
      }
    });

    test('Seuils de précision GPS - Zone Faible (>30m)', () {
      for (double accuracy = 30.0; accuracy <= 50.0; accuracy += 5.0) {
        final status = GpsService.getGpsStatus(accuracy);
        final color = GpsService.getGpsStatusColor(status);
        final text = GpsService.getGpsStatusText(status);

        expect(status, GpsStatus.poor);
        expect(color, Colors.red);
        expect(text, 'SIGNAL FAIBLE');
      }
    });

    test('Cohérence des fonctions de présentation', () {
      final testAccuracies = [5.0, 12.0, 20.0, 40.0];

      for (final accuracy in testAccuracies) {
        final status = GpsService.getGpsStatus(accuracy);

        // Vérifie que chaque statut a une couleur et un texte cohérents
        final color = GpsService.getGpsStatusColor(status);
        final text = GpsService.getGpsStatusText(status);
        final detailedText = GpsService.getGpsDetailedStatusText(status);

        expect(color, isA<Color>());
        expect(text, isA<String>());
        expect(text.isNotEmpty, true);
        expect(detailedText, isA<String>());
        expect(detailedText.isNotEmpty, true);
      }
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

  group('GPS Service Tests - Vocabulaire persisté', () {
    test('Conversion statut -> label', () {
      expect(GpsService.statusToLabel(GpsStatus.excellent), 'Vert');
      expect(GpsService.statusToLabel(GpsStatus.good), 'Jaune');
      expect(GpsService.statusToLabel(GpsStatus.medium), 'Orange');
      expect(GpsService.statusToLabel(GpsStatus.poor), 'Rouge');
    });

    test('Conversion label -> statut', () {
      expect(GpsService.statusFromLabel('Vert'), GpsStatus.excellent);
      expect(GpsService.statusFromLabel('Jaune'), GpsStatus.good);
      expect(GpsService.statusFromLabel('Orange'), GpsStatus.medium);
      expect(GpsService.statusFromLabel('Rouge'), GpsStatus.poor);
      expect(GpsService.statusFromLabel('Inconnu'), null);
      expect(GpsService.statusFromLabel('InvalidLabel'), null);
    });

    test('getGpsStatusLabel depuis précision', () {
      expect(GpsService.getGpsStatusLabel(5.0), 'Vert');
      expect(GpsService.getGpsStatusLabel(10.0), 'Jaune');
      expect(GpsService.getGpsStatusLabel(20.0), 'Orange');
      expect(GpsService.getGpsStatusLabel(40.0), 'Rouge');
      expect(GpsService.getGpsStatusLabel(null), 'Inconnu');
    });

    test('Cohérence label -> couleur', () {
      expect(GpsService.getColorForStatusLabel('Vert'), Colors.green);
      expect(GpsService.getColorForStatusLabel('Jaune'), Colors.amber);
      expect(GpsService.getColorForStatusLabel('Orange'), Colors.orange);
      expect(GpsService.getColorForStatusLabel('Rouge'), Colors.red);
      expect(
        GpsService.getColorForStatusLabel('Inconnu'),
        Colors.grey.shade300,
      );
      expect(
        GpsService.getColorForStatusLabel('InvalidLabel'),
        Colors.grey.shade300,
      );
    });

    test('Cohérence label -> icône', () {
      expect(GpsService.getGpsStatusIcon('Vert'), Icons.gps_fixed);
      expect(GpsService.getGpsStatusIcon('Jaune'), Icons.gps_fixed);
      expect(GpsService.getGpsStatusIcon('Orange'), Icons.location_searching);
      expect(GpsService.getGpsStatusIcon('Rouge'), Icons.gps_off);
      expect(GpsService.getGpsStatusIcon('Inconnu'), Icons.help_outline);
      expect(GpsService.getGpsStatusIcon('InvalidLabel'), Icons.help_outline);
    });

    test('Cohérence label -> description', () {
      expect(
        GpsService.getGpsStatusDescription('Vert'),
        'Précision excellente',
      );
      expect(GpsService.getGpsStatusDescription('Jaune'), 'Précision bonne');
      expect(GpsService.getGpsStatusDescription('Orange'), 'Précision moyenne');
      expect(GpsService.getGpsStatusDescription('Rouge'), 'Précision faible');
      expect(
        GpsService.getGpsStatusDescription('Inconnu'),
        'Signal inconnu (import sans métadonnées)',
      );
      expect(
        GpsService.getGpsStatusDescription('InvalidLabel'),
        'Signal inconnu (import sans métadonnées)',
      );
    });

    test('Round-trip: précision -> label -> statut', () {
      final testAccuracies = [5.0, 10.0, 20.0, 40.0];

      for (final accuracy in testAccuracies) {
        final originalStatus = GpsService.getGpsStatus(accuracy);
        final label = GpsService.statusToLabel(originalStatus);
        final recoveredStatus = GpsService.statusFromLabel(label);

        expect(recoveredStatus, originalStatus);
      }
    });
  });

  group('GPS Service Tests - Calcul de distance (Haversine)', () {
    // Helper pour créer un Waypoint minimal
    Waypoint wp(double lat, double lon) => Waypoint(
      name: 'Test',
      latitude: lat,
      longitude: lon,
      createdAt: DateTime(2024, 1, 1),
    );

    test('Deux coordonnées identiques -> distance 0', () {
      final d = GpsService.distanceToWaypoint(
        const LatLng(43.5, 3.9),
        wp(43.5, 3.9),
      );
      expect(d, 0.0);
    });

    test('Déplacement de 1 degré en latitude -> ~111 195 m', () {
      // À longitude constante (3.9), 1 degré de latitude = pi * R / 180
      // avec R = 6371000 m -> 111194.927 m (exact).
      final d = GpsService.distanceToWaypoint(
        const LatLng(43.5, 3.9),
        wp(44.5, 3.9),
      );
      expect(d, closeTo(111194.927, 0.1));
    });

    test('Déplacement de 1 degré en longitude à l\'équateur -> ~111 195 m', () {
      final d = GpsService.distanceToWaypoint(
        const LatLng(0.0, 0.0),
        wp(0.0, 1.0),
      );
      expect(d, closeTo(111194.927, 0.1));
    });

    test('Déplacement de 1 degré en longitude à 45° -> ~78 626 m', () {
      // Tolérance 2 m : l'écart vient de la différence entre le calcul
      // Haversine (code) et l'approximation cos(45)*111195 (calcul théorique).
      final d = GpsService.distanceToWaypoint(
        const LatLng(45.0, 0.0),
        wp(45.0, 1.0),
      );
      expect(d, closeTo(78626.188, 2.0));
    });

    test(
      'Distance Paris -> Lyon -> ~392 287 m (ordre de grandeur réaliste)',
      () {
        // Paris  : 48.8566 N, 2.3522 E
        // Lyon   : 45.7640 N, 4.8357 E
        // Distance à vol d'oiseau référencée : ~392 km.
        // Tolérance 5 km : assez large pour absorber les différences entre
        // modèle sphérique de Haversine et valeurs de référence réelles.
        final d = GpsService.distanceToWaypoint(
          const LatLng(48.8566, 2.3522),
          wp(45.7640, 4.8357),
        );
        expect(d, closeTo(392287.0, 5000.0));
      },
    );

    test('Symétrie : distance(A, B) == distance(B, A)', () {
      const a = LatLng(43.5, 3.9);
      final b = wp(44.0, 4.0);

      final dAB = GpsService.distanceToWaypoint(a, b);

      // Pour la symétrie, on recrée un Waypoint équivalent à A.
      final aAsWp = Waypoint(
        name: 'A',
        latitude: a.latitude,
        longitude: a.longitude,
        createdAt: DateTime(2024, 1, 1),
      );
      final dBA = GpsService.distanceToWaypoint(const LatLng(44.0, 4.0), aAsWp);

      // Haversine est strictement symétrique.
      expect(dAB, closeTo(dBA, 1e-6));
    });

    test('Distance nulle entre LatLng et Waypoint équivalents', () {
      final d = GpsService.distanceToWaypoint(
        const LatLng(48.8566, 2.3522),
        wp(48.8566, 2.3522),
      );
      expect(d, 0.0);
    });
  });
}
