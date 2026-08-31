import 'package:flutter_test/flutter_test.dart';
import 'package:my_spots/models/fishing_port.dart';

void main() {
  group('FishingPort - Model Tests', () {
    group('Construction', () {
      test('FishingPort standard construction', () {
        final port = FishingPort(
          key: 'test_port',
          name: 'Test Port',
          weatherUrl: 'https://example.com/weather',
          latitude: 43.5,
          longitude: 3.9,
        );

        expect(port.key, 'test_port');
        expect(port.name, 'Test Port');
        expect(port.weatherUrl, 'https://example.com/weather');
        expect(port.latitude, 43.5);
        expect(port.longitude, 3.9);
        expect(port.url, 'https://example.com/weather');
      });

      test('FishingPort.custom construction', () {
        final port = FishingPort.custom(
          name: 'Custom Port',
          weatherUrl: 'https://custom.com/weather',
          latitude: 48.8,
          longitude: -4.5,
        );

        expect(port.key, 'Custom Port');
        expect(port.name, 'Custom Port');
        expect(port.weatherUrl, 'https://custom.com/weather');
      });

      test('FishingPort.legacy construction', () {
        final port = FishingPort.legacy(
          name: 'Legacy Port',
          url: 'https://legacy.com/weather',
        );

        expect(port.name, 'Legacy Port');
        expect(port.url, 'https://legacy.com/weather');
      });

      test('FishingPort sans coordonnees optionnelles', () {
        final port = FishingPort(
          key: 'simple',
          name: 'Simple Port',
          weatherUrl: 'https://simple.com/weather',
        );

        expect(port.latitude, isNull);
        expect(port.longitude, isNull);
      });
    });

    group('Serialization - toMap / fromMap', () {
      test('toMap retourne tous les champs', () {
        final port = FishingPort(
          key: 'serialize_test',
          name: 'Serialize Test',
          weatherUrl: 'https://test.com/weather',
          latitude: 45.0,
          longitude: -5.0,
        );

        final map = port.toMap();

        expect(map['key'], 'serialize_test');
        expect(map['name'], 'Serialize Test');
        expect(map['weatherUrl'], 'https://test.com/weather');
        expect(map['latitude'], 45.0);
        expect(map['longitude'], -5.0);
      });

      test('toMap omet les coordonnees null', () {
        final port = FishingPort(
          key: 'no_coords',
          name: 'No Coords Port',
          weatherUrl: 'https://nocoords.com/weather',
        );

        final map = port.toMap();

        expect(map.containsKey('latitude'), false);
        expect(map.containsKey('longitude'), false);
      });

      test('fromMap cree le port correctement', () {
        final map = {
          'key': 'from_map_test',
          'name': 'From Map Test',
          'weatherUrl': 'https://frommap.com/weather',
          'latitude': 50.0,
          'longitude': 10.0,
        };

        final port = FishingPort.fromMap(map);

        expect(port.key, 'from_map_test');
        expect(port.name, 'From Map Test');
        expect(port.weatherUrl, 'https://frommap.com/weather');
        expect(port.latitude, 50.0);
        expect(port.longitude, 10.0);
      });

      test('fromMap supporte la cle url legacy', () {
        final map = {
          'name': 'Legacy URL Port',
          'url': 'https://legacy.com/weather',
        };

        final port = FishingPort.fromMap(map);

        expect(port.weatherUrl, 'https://legacy.com/weather');
      });

      test('fromMap utilise name comme key fallback', () {
        final map = {
          'name': 'Fallback Key Port',
          'weatherUrl': 'https://fallback.com/weather',
        };

        final port = FishingPort.fromMap(map);

        expect(port.key, 'Fallback Key Port');
      });
    });

    group('Serialization - JSON', () {
      test('toJson delegue a toMap', () {
        final port = FishingPort(
          key: 'json_test',
          name: 'JSON Test',
          weatherUrl: 'https://json.com/weather',
        );

        final json = port.toJson();

        expect(json['key'], 'json_test');
        expect(json['name'], 'JSON Test');
        expect(json['weatherUrl'], 'https://json.com/weather');
      });

      test('fromJson delegue a fromMap', () {
        final json = {
          'key': 'from_json_test',
          'name': 'From JSON Test',
          'weatherUrl': 'https://fromjson.com/weather',
        };

        final port = FishingPort.fromJson(json);

        expect(port.key, 'from_json_test');
        expect(port.name, 'From JSON Test');
      });
    });

    group('Equality', () {
      test('Deux ports avec meme key sont egaux', () {
        final port1 = FishingPort(
          key: 'same_key',
          name: 'Port One',
          weatherUrl: 'https://one.com',
        );

        final port2 = FishingPort(
          key: 'same_key',
          name: 'Port Two Different Name',
          weatherUrl: 'https://two.com',
        );

        expect(port1 == port2, true);
        expect(port1.hashCode, port2.hashCode);
      });

      test('Deux ports avec differentes keys ne sont pas egaux', () {
        final port1 = FishingPort(
          key: 'key_one',
          name: 'Same Name',
          weatherUrl: 'https://same.com',
        );

        final port2 = FishingPort(
          key: 'key_two',
          name: 'Same Name',
          weatherUrl: 'https://same.com',
        );

        expect(port1 == port2, false);
      });

      test('Identique est compare a lui-meme', () {
        final port = FishingPort(
          key: 'identical',
          name: 'Identical Port',
          weatherUrl: 'https://identical.com',
        );

        expect(port == port, true);
      });
    });

    group('toString', () {
      test('toString retourne le nom du port', () {
        final port = FishingPort(
          key: 'tostring',
          name: 'ToString Port',
          weatherUrl: 'https://tostring.com',
        );

        expect(port.toString(), 'ToString Port');
      });
    });
  });
}