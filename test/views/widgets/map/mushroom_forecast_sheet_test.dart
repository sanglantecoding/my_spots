import 'package:flutter_test/flutter_test.dart';
import 'package:my_spots/models/mushroom/mushroom_forecast.dart';
import 'package:my_spots/views/widgets/map/mushroom_forecast_sheet.dart';

void main() {
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
}
