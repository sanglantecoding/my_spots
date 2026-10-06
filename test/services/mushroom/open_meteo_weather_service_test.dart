import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:my_spots/models/mushroom/soil_moisture_data.dart';
import 'package:my_spots/models/mushroom/weather_day.dart';
import 'package:my_spots/services/mushroom/open_meteo_weather_service.dart';

void main() {
  group('parseJson – météo', () {
    test('parse les champs daily correctement', () {
      final json = _buildSimpleJson(historicalDays: 3, forecastDays: 2);
      final result = OpenMeteoWeatherService.parseJson(json, forecastDays: 2);

      expect(result.weatherDays.length, 5);
      final d0 = result.weatherDays[0];
      expect(d0.date, DateTime(2026, 1, 1));
      expect(d0.kind, WeatherDataKind.historical);
      expect(d0.precipitation, 1.0);
      expect(d0.temperatureMin, 5.0);
      expect(d0.temperatureMax, 10.0);
      expect(d0.temperatureMean, 7.5);
      expect(d0.windSpeed, 3.0);
      expect(d0.windGust, 5.0);
      expect(d0.et0, 0.5);
    });

    test('converti hourly humidity et solar en moyenne journalière', () {
      // Helper génère 2 heures par jour.
      // Jour 1 (historical) → indices 0-1 ; Jour 2 (forecast) → indices 2-3.
      final json = _buildSimpleJson(
        historicalDays: 1,
        forecastDays: 1,
        humidityByHour: [70.0, 80.0, 90.0, 90.0],
        solarByHour: [200.0, 300.0, 400.0, 400.0],
      );
      final result = OpenMeteoWeatherService.parseJson(json, forecastDays: 1);
      final hist = result.weatherDays.firstWhere(
        (d) => d.kind == WeatherDataKind.historical,
      );
      // moyenne historique : (70 + 80) / 2 = 75
      expect(hist.humidity, closeTo(75.0, 0.001));
      // moyenne historique : (200 + 300) / 2 = 250
      expect(hist.solarRadiation, closeTo(250.0, 0.001));
    });

    test('converti humidité m³/m³ → % volumique (×100)', () {
      final json = _buildSimpleJson(
        historicalDays: 1,
        forecastDays: 1,
        soilMoisture01: [0.25, 0.35],
      );
      final result = OpenMeteoWeatherService.parseJson(json, forecastDays: 1);
      final layer01 = result.soilLayers.firstWhere(
        (s) => s.depthStart == 0 && s.depthEnd == 1,
      );
      // moyenne (0.25 + 0.35) / 2 = 0.30 → ×100 = 30 %
      expect(layer01.soilMoisture, closeTo(30.0, 0.001));
      expect(layer01.soilWaterIndex, isNull);
    });

    test('séparation historical / forecast – index-based', () {
      final json = _buildSimpleJson(historicalDays: 60, forecastDays: 8);
      final result = OpenMeteoWeatherService.parseJson(json, forecastDays: 8);

      final historical = result.weatherDays
          .where((d) => d.kind == WeatherDataKind.historical)
          .toList();
      final forecast = result.weatherDays
          .where((d) => d.kind == WeatherDataKind.forecast)
          .toList();

      expect(historical.length, 60);
      expect(forecast.length, 8);
    });

    test('J+0 est seulement dans forecast (pas de double comptage)', () {
      final json = _buildSimpleJson(historicalDays: 60, forecastDays: 8);
      final result = OpenMeteoWeatherService.parseJson(json, forecastDays: 8);

      final historical = result.weatherDays
          .where((d) => d.kind == WeatherDataKind.historical)
          .toList();
      final forecast = result.weatherDays
          .where((d) => d.kind == WeatherDataKind.forecast)
          .toList();

      // J+0 = first forecast day = day 61 in the sequence (1-indexed)
      final j0 = forecast.first.date;
      final j0InHistorical = historical.any(
        (d) =>
            d.date.year == j0.year &&
            d.date.month == j0.month &&
            d.date.day == j0.day,
      );
      expect(
        j0InHistorical,
        isFalse,
        reason: 'J+0 ne doit pas être présent dans historical',
      );
      expect(forecast.first.date, j0);
    });

    test('champs null dans le JSON restent null dans WeatherDay', () {
      final json = <String, dynamic>{
        'daily': {
          'time': ['2026-01-01'],
          'precipitation_sum': [null],
          'temperature_2m_min': [null],
          'temperature_2m_max': [null],
          'temperature_2m_mean': [null],
          'wind_speed_10m_max': [null],
          'wind_gusts_10m_max': [null],
          'et0_fao_evapotranspiration': [null],
        },
        'hourly': {
          'time': ['2026-01-01T00:00'],
          'relative_humidity_2m': [null],
          'shortwave_radiation': [null],
          'soil_moisture_0_1cm': [null],
          'soil_moisture_1_3cm': [null],
          'soil_moisture_3_9cm': [null],
          'soil_moisture_9_27cm': [null],
          'soil_moisture_27_81cm': [null],
          'soil_temperature_6cm': [null],
          'soil_temperature_18cm': [null],
          'soil_temperature_54cm': [null],
        },
      };
      final result = OpenMeteoWeatherService.parseJson(json, forecastDays: 1);
      final day = result.weatherDays.first;
      expect(day.precipitation, isNull);
      expect(day.temperatureMin, isNull);
      expect(day.temperatureMax, isNull);
      expect(day.temperatureMean, isNull);
      expect(day.windSpeed, isNull);
      expect(day.windGust, isNull);
      expect(day.et0, isNull);
      expect(day.humidity, isNull);
      expect(day.solarRadiation, isNull);
    });
  });

  group('parseJson – sol', () {
    test('5 couches de profondeur natives avec bornes respectées', () {
      final json = _buildSimpleJson(historicalDays: 1, forecastDays: 1);
      final result = OpenMeteoWeatherService.parseJson(json, forecastDays: 1);

      final depths = result.soilLayers
          .map((s) => (s.depthStart, s.depthEnd))
          .toSet();

      expect(
        depths,
        containsAllInOrder([
          (0.0, 1.0),
          (1.0, 3.0),
          (3.0, 9.0),
          (9.0, 27.0),
          (27.0, 81.0),
        ]),
      );
    });

    test('agrégation hourly → moyenne journalière pour chaque couche', () {
      // Helper = 2h/jour. 2 jours = 4 heures au total.
      // On fournit 2 valeurs → utilisées pour les 2 heures du jour 1 (historique).
      final json = _buildSimpleJson(
        historicalDays: 1,
        forecastDays: 1,
        // Couche 3-9 cm utilise soil_temperature_6cm
        soilMoisture39: [0.10, 0.30],
        soilTemp6: [13.0, 15.0],
        // Couche 9-27 cm utilise soil_temperature_18cm
        soilMoisture927: [0.20, 0.40],
        soilTemp18: [11.0, 17.0],
      );
      final result = OpenMeteoWeatherService.parseJson(json, forecastDays: 1);

      final layer39 = result.soilLayers.firstWhere(
        (s) => s.depthStart == 3 && s.depthEnd == 9,
      );
      // (0.10 + 0.30) / 2 = 0.20 → ×100 = 20 %
      expect(layer39.soilMoisture, closeTo(20.0, 0.001));
      // (13.0 + 15.0) / 2 = 14.0
      expect(layer39.soilTemperature, closeTo(14.0, 0.001));

      final layer927 = result.soilLayers.firstWhere(
        (s) => s.depthStart == 9 && s.depthEnd == 27,
      );
      // (0.20 + 0.40) / 2 = 0.30 → ×100 = 30 %
      expect(layer927.soilMoisture, closeTo(30.0, 0.001));
      // (11.0 + 17.0) / 2 = 14.0
      expect(layer927.soilTemperature, closeTo(14.0, 0.001));
    });

    test(
      'appairage températures sur les couches contenant leur profondeur',
      () {
        final json = _buildSimpleJson(
          historicalDays: 1,
          forecastDays: 1,
          soilTemp6: [6.6],
          soilTemp18: [18.8],
          soilTemp54: [54.4],
        );
        final result = OpenMeteoWeatherService.parseJson(json, forecastDays: 1);

        // 0-1 et 1-3 n'ont pas de température
        final l01 = result.soilLayers.firstWhere(
          (s) => s.depthStart == 0 && s.depthEnd == 1,
        );
        final l13 = result.soilLayers.firstWhere(
          (s) => s.depthStart == 1 && s.depthEnd == 3,
        );
        final l39 = result.soilLayers.firstWhere(
          (s) => s.depthStart == 3 && s.depthEnd == 9,
        );
        final l927 = result.soilLayers.firstWhere(
          (s) => s.depthStart == 9 && s.depthEnd == 27,
        );
        final l2781 = result.soilLayers.firstWhere(
          (s) => s.depthStart == 27 && s.depthEnd == 81,
        );

        expect(l01.soilTemperature, isNull);
        expect(l13.soilTemperature, isNull);
        expect(l39.soilTemperature, closeTo(6.6, 0.001));
        expect(l927.soilTemperature, closeTo(18.8, 0.001));
        expect(l2781.soilTemperature, closeTo(54.4, 0.001));
      },
    );

    test('kind=historical avant forecastDays, kind=forecast après', () {
      final json = _buildSimpleJson(historicalDays: 2, forecastDays: 2);
      final result = OpenMeteoWeatherService.parseJson(json, forecastDays: 2);

      // Grouper SoilMoistureData par date
      final byDate = <DateTime, List<SoilMoistureData>>{};
      for (final s in result.soilLayers) {
        byDate.putIfAbsent(s.date, () => []).add(s);
      }
      final dates = byDate.keys.toList()..sort();

      expect(dates.length, 4);
      expect(
        byDate[dates[0]]!.every(
          (s) => s.kind == SoilMoistureDataKind.historical,
        ),
        isTrue,
      );
      expect(
        byDate[dates[1]]!.every(
          (s) => s.kind == SoilMoistureDataKind.historical,
        ),
        isTrue,
      );
      expect(
        byDate[dates[2]]!.every((s) => s.kind == SoilMoistureDataKind.forecast),
        isTrue,
      );
      expect(
        byDate[dates[3]]!.every((s) => s.kind == SoilMoistureDataKind.forecast),
        isTrue,
      );
    });

    test('source renseignée avec le modèle', () {
      final json = _buildSimpleJson(historicalDays: 1, forecastDays: 1);
      final result = OpenMeteoWeatherService.parseJson(
        json,
        forecastDays: 1,
        sourceModel: 'ecmwf_ifs025',
      );
      for (final s in result.soilLayers) {
        expect(s.source, 'ecmwf_ifs025');
      }
    });

    test('valeurs null de sol restent null (pas de zéro artificiel)', () {
      final json = <String, dynamic>{
        'daily': {
          'time': ['2026-01-01'],
          'precipitation_sum': [0.0],
          'temperature_2m_min': [0.0],
          'temperature_2m_max': [0.0],
          'temperature_2m_mean': [0.0],
          'wind_speed_10m_max': [0.0],
          'wind_gusts_10m_max': [0.0],
          'et0_fao_evapotranspiration': [0.0],
        },
        'hourly': {
          'time': ['2026-01-01T00:00', '2026-01-01T12:00'],
          'relative_humidity_2m': [0.0, 0.0],
          'shortwave_radiation': [0.0, 0.0],
          'soil_moisture_0_1cm': [null, null],
          'soil_moisture_1_3cm': [null, null],
          'soil_moisture_3_9cm': [null, null],
          'soil_moisture_9_27cm': [null, null],
          'soil_moisture_27_81cm': [null, null],
          'soil_temperature_6cm': [null, null],
          'soil_temperature_18cm': [null, null],
          'soil_temperature_54cm': [null, null],
        },
      };
      final result = OpenMeteoWeatherService.parseJson(json, forecastDays: 1);
      for (final s in result.soilLayers) {
        expect(s.soilMoisture, isNull);
        expect(s.soilWaterIndex, isNull);
      }
    });
  });

  group('WeatherService integration – MockClient', () {
    test('historique = 60 jours J-60 → J-1', () async {
      final client = MockClient((request) async {
        return Response(
          jsonEncode(_buildSimpleJson(historicalDays: 60, forecastDays: 8)),
          200,
        );
      });
      final svc = OpenMeteoWeatherService(client: client);
      final result = await svc.getHistoricalWeather(
        lat: 44.0,
        lng: 3.0,
        days: 60,
      );
      // Nombre de jours = 60, tous historical
      expect(result.length, 60);
      expect(result.every((d) => d.kind == WeatherDataKind.historical), isTrue);
      // Premier jour historique = J-60 = 2026-01-01 (start du helper)
      expect(result.first.date, DateTime(2026, 1, 1));
      // Dernier jour historique = J-1 = veille du J+0 = 2026-03-01
      expect(result.last.date, DateTime(2026, 3, 1));
    });

    test('prévision = 8 jours J+0 → J+7 avec days:7', () async {
      final client = MockClient((request) async {
        return Response(
          jsonEncode(_buildSimpleJson(historicalDays: 60, forecastDays: 8)),
          200,
        );
      });
      final svc = OpenMeteoWeatherService(client: client);
      final result = await svc.getWeatherForecast(lat: 44.0, lng: 3.0, days: 7);
      // days:7 → convention J+0 inclus = 8 jours au total
      expect(result.length, 8);
      expect(result.every((d) => d.kind == WeatherDataKind.forecast), isTrue);
      // Premier jour forecast = J+0 = lendemain de J-1 = 2026-03-02
      expect(result.first.date, DateTime(2026, 3, 2));
      // Dernier jour forecast = J+7 = 2026-03-09
      expect(result.last.date, DateTime(2026, 3, 9));
    });

    test(
      'getSoilMoisture retourne 5 couches par jour avec profondeurs natives',
      () async {
        final client = MockClient((request) async {
          return Response(
            jsonEncode(_buildSimpleJson(historicalDays: 2, forecastDays: 2)),
            200,
          );
        });
        final svc = OpenMeteoWeatherService(client: client);
        final result = await svc.getSoilMoisture(lat: 44.0, lng: 3.0);
        // 4 jours × 5 couches
        expect(result.length, 20);
        final depthSpans = result
            .map((s) => '${s.depthStart}-${s.depthEnd}')
            .toSet();
        expect(depthSpans, {
          '0.0-1.0',
          '1.0-3.0',
          '3.0-9.0',
          '9.0-27.0',
          '27.0-81.0',
        });
      },
    );

    test('HTTP non-200 lance ClientException', () async {
      final client = MockClient((request) async => Response('oops', 500));
      final svc = OpenMeteoWeatherService(client: client);
      expect(
        () => svc.getHistoricalWeather(lat: 0, lng: 0, days: 1),
        throwsA(isA<ClientException>()),
      );
    });

    test('cache interne évite les doubles appels pour mêmes coords', () async {
      var callCount = 0;
      final client = MockClient((request) async {
        callCount++;
        return Response(
          jsonEncode(_buildSimpleJson(historicalDays: 1, forecastDays: 1)),
          200,
        );
      });
      final svc = OpenMeteoWeatherService(client: client);
      await svc.getHistoricalWeather(lat: 44.0, lng: 3.0, days: 1);
      await svc.getWeatherForecast(lat: 44.0, lng: 3.0, days: 1);
      expect(callCount, 1, reason: 'même coordonnées → un seul appel HTTP');
    });

    test('params URL contiennent modèle et unités explicités', () async {
      late final Uri captured;
      final client = MockClient((request) async {
        captured = request.url;
        return Response(
          jsonEncode(_buildSimpleJson(historicalDays: 1, forecastDays: 1)),
          200,
        );
      });
      final svc = OpenMeteoWeatherService(client: client);
      await svc.getHistoricalWeather(lat: 44.12345, lng: 3.6789, days: 1);
      expect(captured.queryParameters['models'], 'ecmwf_ifs025');
      expect(captured.queryParameters['past_days'], '60');
      expect(captured.queryParameters['forecast_days'], '8');
      expect(captured.queryParameters['timezone'], 'auto');
      expect(captured.queryParameters['wind_speed_unit'], 'ms');
      expect(captured.queryParameters['temperature_unit'], 'celsius');
      expect(captured.queryParameters['precipitation_unit'], 'mm');
    });
  });
}

// ============================================================================
// Générateur de JSON Open-Meteo simplifié pour tests
// ============================================================================
Map<String, dynamic> _buildSimpleJson({
  required int historicalDays,
  required int forecastDays,
  List<double>? humidityByHour,
  List<double>? solarByHour,
  List<double>? soilMoisture01,
  List<double>? soilMoisture13,
  List<double>? soilMoisture39,
  List<double>? soilMoisture927,
  List<double>? soilMoisture2781,
  List<double>? soilTemp6,
  List<double>? soilTemp18,
  List<double>? soilTemp54,
}) {
  final totalDays = historicalDays + forecastDays;
  final start = DateTime(2026, 1, 1);

  final dailyTime = List<String>.generate(totalDays, (i) {
    final d = start.add(Duration(days: i));
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  });

  final daily = <String, dynamic>{
    'time': dailyTime,
    'precipitation_sum': List<double>.generate(totalDays, (i) => (i + 1) * 1.0),
    'temperature_2m_min': List<double>.generate(
      totalDays,
      (i) => 5.0 + i * 0.1,
    ),
    'temperature_2m_max': List<double>.generate(
      totalDays,
      (i) => 10.0 + i * 0.1,
    ),
    'temperature_2m_mean': List<double>.generate(
      totalDays,
      (i) => 7.5 + i * 0.1,
    ),
    'wind_speed_10m_max': List<double>.generate(
      totalDays,
      (i) => 3.0 + i * 0.05,
    ),
    'wind_gusts_10m_max': List<double>.generate(
      totalDays,
      (i) => 5.0 + i * 0.1,
    ),
    'et0_fao_evapotranspiration': List<double>.generate(
      totalDays,
      (i) => 0.5 + i * 0.02,
    ),
  };

  // Heures : 2 heures par jour pour simplifier
  final totalHours = totalDays * 2;
  final hourlyTime = List<String>.generate(totalHours, (i) {
    final dayIdx = i ~/ 2;
    final hour = (i % 2) * 12;
    final d = start.add(Duration(days: dayIdx, hours: hour));
    return d.toIso8601String();
  });

  List<double> fill2(List<double>? provided, double base) {
    if (provided != null) return provided;
    return List<double>.generate(totalHours, (i) => base + i * 0.01);
  }

  final hourly = <String, dynamic>{
    'time': hourlyTime,
    'relative_humidity_2m': fill2(humidityByHour, 70.0),
    'shortwave_radiation': fill2(solarByHour, 200.0),
    'soil_moisture_0_1cm': fill2(soilMoisture01, 0.20),
    'soil_moisture_1_3cm': fill2(soilMoisture13, 0.22),
    'soil_moisture_3_9cm': fill2(soilMoisture39, 0.25),
    'soil_moisture_9_27cm': fill2(soilMoisture927, 0.28),
    'soil_moisture_27_81cm': fill2(soilMoisture2781, 0.30),
    'soil_temperature_6cm': fill2(soilTemp6, 10.0),
    'soil_temperature_18cm': fill2(soilTemp18, 12.0),
    'soil_temperature_54cm': fill2(soilTemp54, 14.0),
  };

  return {'daily': daily, 'hourly': hourly};
}
