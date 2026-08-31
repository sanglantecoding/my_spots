import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_spots/app_settings.dart';

void main() {
  group('AppSettings - Persistance et Migration', () {
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SharedPreferences.getInstance();
      AppSettings.speedUnit = SpeedUnit.kmh;
      AppSettings.selectedPortKey = null;
      AppSettings.waypointsVisible = true;
      AppSettings.showWaypointNamesOnMap = true;
      AppSettings.showWaypointDateOnMap = false;
      AppSettings.distanceUnit = DistanceUnit.metric;
      AppSettings.waypointLabelFontSize = 15.0;
      AppSettings.mapType = MapType.standard;
      AppSettings.showSpeedOnMap = false;
      AppSettings.proximityAlarmEnabled = false;
      AppSettings.proximityDistanceX = 100.0;
      AppSettings.proximityDistanceY = 20.0;
      AppSettings.proximityDistanceZ = 5.0;
      AppSettings.showFishingWaypointsOnMap = true;
      AppSettings.showMushroomWaypointsOnMap = true;
      AppSettings.showOtherWaypointsOnMap = true;
      AppSettings.energySavingMode = false;
      AppSettings.bathymetryOverlayEnabled = false;
      AppSettings.bathymetryOverlayOpacity = 0.7;
      AppSettings.favoritePorts = [];
    });

    group('loadSettings', () {
      test('Valeurs par defaut au premier lancement', () async {
        SharedPreferences.setMockInitialValues({});
        await AppSettings.loadSettings();
        expect(AppSettings.selectedPortKey, 'palavas_les_flots');
        expect(AppSettings.speedUnit, SpeedUnit.kmh);
        expect(AppSettings.mapType, MapType.standard);
      });

      test('Valeurs chargees depuis SharedPreferences', () async {
        SharedPreferences.setMockInitialValues({
          'selected_port': 'sete',
          'speed_unit': SpeedUnit.knots.index,
          'map_type': MapType.marine.index,
          'distance_unit': DistanceUnit.nautical.index,
          'waypoints_visible': false,
          'proximity_alarm_enabled': true,
        });
        await AppSettings.loadSettings();
        expect(AppSettings.selectedPortKey, 'sete');
        expect(AppSettings.speedUnit, SpeedUnit.knots);
        expect(AppSettings.mapType, MapType.marine);
        expect(AppSettings.distanceUnit, DistanceUnit.nautical);
      });

      test('Valeurs invalides utilisent les defauts', () async {
        SharedPreferences.setMockInitialValues({
          'speed_unit': 999,
          'waypoint_label_font_size': 25.0,
        });
        await AppSettings.loadSettings();
        expect(AppSettings.waypointLabelFontSize, 20.0);
      });
    });

    group('saveSettings', () {
      test('saveSpeedUnit persiste la valeur', () async {
        await AppSettings.saveSpeedUnit(SpeedUnit.knots);
        expect(AppSettings.speedUnit, SpeedUnit.knots);
      });

      test('saveDistanceUnit persiste la valeur', () async {
        await AppSettings.saveDistanceUnit(DistanceUnit.nautical);
        expect(AppSettings.distanceUnit, DistanceUnit.nautical);
      });

      test('saveMapType persiste la valeur', () async {
        await AppSettings.saveMapType(MapType.hiking);
        expect(AppSettings.mapType, MapType.hiking);
      });

      test('saveWaypointLabelFontSize clamp', () async {
        await AppSettings.saveWaypointLabelFontSize(5.0);
        expect(AppSettings.waypointLabelFontSize, 10.0);
        await AppSettings.saveWaypointLabelFontSize(25.0);
        expect(AppSettings.waypointLabelFontSize, 20.0);
      });

      test('saveProximityDistances persiste', () async {
        await AppSettings.saveProximityDistances(x: 200.0, y: 50.0, z: 10.0);
        expect(AppSettings.proximityDistanceX, 200.0);
      });

      test('saveBathymetryOverlayOpacity clamp', () async {
        await AppSettings.saveBathymetryOverlayOpacity(-0.5);
        expect(AppSettings.bathymetryOverlayOpacity, 0.0);
        await AppSettings.saveBathymetryOverlayOpacity(1.5);
        expect(AppSettings.bathymetryOverlayOpacity, 1.0);
      });
    });

    group('URLs', () {
      test('getWeatherUrl port selectionne', () async {
        SharedPreferences.setMockInitialValues({'selected_port': 'sete'});
        await AppSettings.loadSettings();
        expect(AppSettings.getWeatherUrl(), contains('sete'));
      });

      test('getWeatherUrl URL par defaut quand port introuvable', () async {
        SharedPreferences.setMockInitialValues({
          'selected_port': 'port_qui_n_existe_pas',
        });
        await AppSettings.loadSettings();
        expect(AppSettings.getWeatherUrl(), AppSettings.defaultWeatherUrl);
      });

      test('getMapTileUrl marine exception', () {
        AppSettings.mapType = MapType.marine;
        expect(() => AppSettings.getMapTileUrl(), throwsA(isA<StateError>()));
      });

      test('getMapTileUrl standard', () {
        AppSettings.mapType = MapType.standard;
        expect(AppSettings.getMapTileUrl(), contains('openstreetmap.org'));
      });

      test('getMapTileUrl relief', () {
        AppSettings.mapType = MapType.relief;
        expect(AppSettings.getMapTileUrl(), contains('opentopomap.org'));
      });
    });
  });
}
