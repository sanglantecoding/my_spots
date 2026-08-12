import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:my_spots/services/gps_service.dart';

void main() {
  group('GPS Service Tests - Cohérence des couleurs et textes', () {
    test('Seuils de précision GPS - Zone Excellent (0-8m)', () {
      // Test de différentes précisions dans la zone excellente
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
      // Test de différentes précisions dans la zone correcte
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
      // Test de différentes précisions dans la zone moyenne
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
      // Test de différentes précisions dans la zone faible
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
      // Test que toutes les fonctions retournent des résultats cohérents
      final testAccuracies = [5.0, 12.0, 20.0, 40.0];

      for (final accuracy in testAccuracies) {
        final status1 = GpsService.getGpsStatus(accuracy);
        final color1 = GpsService.getGpsStatusColor(status1);
        final color2 = GpsService.getAccuracyColor(accuracy);

        // Les deux méthodes doivent retourner la même couleur
        expect(color1, color2);

        // Test de cohérence texte détaillé
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
      // Test des valeurs exactes aux limites
      expect(GpsService.getGpsStatus(7.9), GpsStatus.excellent);
      expect(GpsService.getGpsStatus(8.0), GpsStatus.good);
      expect(GpsService.getGpsStatus(14.9), GpsStatus.good);
      expect(GpsService.getGpsStatus(15.0), GpsStatus.medium);
      expect(GpsService.getGpsStatus(29.9), GpsStatus.medium);
      expect(GpsService.getGpsStatus(30.0), GpsStatus.poor);
    });
  });
}
