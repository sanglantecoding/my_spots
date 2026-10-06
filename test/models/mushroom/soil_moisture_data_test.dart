import 'package:flutter_test/flutter_test.dart';
import 'package:my_spots/models/mushroom/soil_moisture_data.dart';

void main() {
  group('SoilMoistureData', () {
    test('creates instance with correct values', () {
      final date = DateTime(2024, 10, 5);
      final moisture = SoilMoistureData(
        date: date,
        depthStart: 0.0,
        depthEnd: 7.0,
        soilMoisture: 30.0,
        soilWaterIndex: 0.5,
      );

      expect(moisture.date, date);
      expect(moisture.depthStart, 0.0);
      expect(moisture.depthEnd, 7.0);
      expect(moisture.soilMoisture, 30.0);
      expect(moisture.soilWaterIndex, 0.5);
    });

    test('creates instance with null optional fields', () {
      final moisture = SoilMoistureData(
        date: DateTime.now(),
        depthStart: 0.0,
        depthEnd: 7.0,
        soilMoisture: 30.0,
      );

      expect(moisture.soilTemperature, isNull);
      expect(moisture.soilWaterIndex, isNull);
      expect(moisture.source, isNull);
    });

    test('mock creates instance with default values', () {
      final moisture = SoilMoistureData.mock();

      expect(moisture.depthStart, 0.0);
      expect(moisture.depthEnd, 7.0);
      expect(moisture.soilMoisture, 30.0);
      expect(moisture.soilTemperature, isNull);
      expect(moisture.soilWaterIndex, isNull);
      expect(moisture.source, isNull);
    });

    test('mock accepts custom values', () {
      final moisture = SoilMoistureData.mock(
        depthStart: 5.0,
        depthEnd: 10.0,
        moisture: 50.0,
        soilTemperature: 15.0,
        swi: 0.8,
        source: 'open-meteo',
      );

      expect(moisture.depthStart, 5.0);
      expect(moisture.depthEnd, 10.0);
      expect(moisture.soilMoisture, 50.0);
      expect(moisture.soilTemperature, 15.0);
      expect(moisture.soilWaterIndex, 0.8);
      expect(moisture.source, 'open-meteo');
    });
  });
}
