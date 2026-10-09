import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:my_spots/app_settings.dart';
import 'package:my_spots/models/mushroom/mushroom_forecast.dart';
import 'package:my_spots/views/widgets/map/mushroom_forecast_sheet.dart';

void main() {
  test('la confiance est libellée comme complétude des données', () {
    expect(mushroomDataAvailabilityLabel(0.83), 'Données disponibles : 83 %');
    expect(
      mushroomConfidenceExplanation,
      'Ce pourcentage mesure la complétude des sources, pas la fiabilité du modèle.',
    );
  });

  testWidgets('la fiche affiche la précision sous l’avertissement', (
    tester,
  ) async {
    AppSettings.offlineModeEnabled = true;
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MushroomForecastSheet(point: LatLng(43.5, 2.7))),
      ),
    );

    expect(find.text(mushroomConfidenceExplanation), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.text(mushroomConfidenceExplanation))
          .style
          ?.fontSize,
      10,
    );
    AppSettings.offlineModeEnabled = false;
  });

  test('le facteur eau signale l’absence de mesure du sol', () {
    expect(mushroomWaterFactorLabel(false), 'Eau (sans mesure du sol)');
    expect(mushroomWaterFactorLabel(true), 'Eau');
  });

  test(
    'la fiche affiche les valeurs du sol sans inventer les valeurs nulles',
    () {
      final forecast = MushroomForecast.mock(
        soilMoisture0To7Percent: 12.34,
        soilMoisture7To28Percent: null,
        soilTemperature0To7C: 8.5,
      );

      expect(
        mushroomSoilValuesLabel(forecast),
        'Sol 0-7 cm : 12.3 % · 7-28 cm : n/d % · '
        'température sol 0-7 cm : 8.5 °C',
      );
    },
  );

  test('la fiche affiche la distribution du sol sur 60 jours', () {
    final forecast = MushroomForecast.mock(
      soilMoisture7To28Min60dPercent: 8,
      soilMoisture7To28Median60dPercent: 24.5,
      soilMoisture7To28Max60dPercent: 41,
      soilMoisture7To28Percentile60d: 80,
    );

    expect(
      mushroomSoilHistoryStatsLabel(forecast),
      'Sol 7-28 cm sur 60 j : min 8.0 % · médiane 24.5 % · max 41.0 % · '
      "aujourd'hui au 80e percentile",
    );
  });

  test('statistiques absentes sont affichées n/d', () {
    expect(
      mushroomSoilHistoryStatsLabel(MushroomForecast.mock()),
      'Sol 7-28 cm sur 60 j : min n/d % · médiane n/d % · max n/d % · '
      "aujourd'hui au n/d percentile",
    );
  });
}
