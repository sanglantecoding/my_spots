import 'package:flutter_test/flutter_test.dart';
import 'package:my_spots/app_settings.dart';
import 'package:my_spots/models/fishing_port.dart';
import 'package:my_spots/services/port_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

FishingPort _p(String key, String name) => FishingPort(
      key: key,
      name: name,
      weatherUrl: 'https://example.com/$key',
    );

void main() {
  final svc = PortService.instance;
  final catalog = [
    _p('a', 'Alpha'),
    _p('b', 'Bravo'),
    _p('c', 'Charlie'),
    _p('d', 'Delta'),
    _p('e', 'Echo'),
    _p('f', 'Foxtrot'),
  ];

  group('orderByFavoritesFirst - selection + favoris', () {
    test('Test 1 : selected=C, favorites=[A,E] -> C, A, E, B, D, F', () {
      final result = svc.orderByFavoritesFirst(
        catalog,
        {'a', 'e'},
        selectedPortKey: 'c',
      );
      expect(result.map((p) => p.key).toList(), ['c', 'a', 'e', 'b', 'd', 'f']);
    });

    test('Test 2 : selected=A (aussi favori), favorites=[A,E] -> A, E, ... (pas de doublon)', () {
      final result = svc.orderByFavoritesFirst(
        catalog,
        {'a', 'e'},
        selectedPortKey: 'a',
      );
      final keys = result.map((p) => p.key).toList();
      expect(keys.first, 'a');
      expect(keys.where((k) => k == 'a').length, 1);
      expect(keys, contains('e'));
    });

    test('Test 3 : selected=null, favorites=[B,D] -> B, D, A, C, E, F', () {
      final result = svc.orderByFavoritesFirst(
        catalog,
        {'b', 'd'},
        selectedPortKey: null,
      );
      expect(result.map((p) => p.key).toList(), ['b', 'd', 'a', 'c', 'e', 'f']);
    });

    test('Test 4 : selected invalide (cle inconnue) -> pas de crash, pas de doublon', () {
      final result = svc.orderByFavoritesFirst(
        catalog,
        {'b'},
        selectedPortKey: 'unknown_key',
      );
      final keys = result.map((p) => p.key).toList();
      expect(keys, ['b', 'a', 'c', 'd', 'e', 'f']);
    });

    test('Test 5 : aucun favori, aucun selectionne -> ordre alphabetique', () {
      final result = svc.orderByFavoritesFirst(catalog, <String>{});
      expect(result.map((p) => p.key).toList(), ['a', 'b', 'c', 'd', 'e', 'f']);
    });

    test('Test 6 : selected=A, aucun favori -> A en premier, reste alphabetique', () {
      final result = svc.orderByFavoritesFirst(
        catalog,
        <String>{},
        selectedPortKey: 'a',
      );
      expect(result.map((p) => p.key).toList(), ['a', 'b', 'c', 'd', 'e', 'f']);
    });
  });

  group('Sete favorite regression - cle normalisee sans accent', () {
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await SharedPreferences.getInstance();
    });

    setUp(() {
      AppSettings.favoritePorts = [];
    });

    test('PortService.getPortByKey("sete") a key="sete" (sans accent)', () {
      final port = PortService.instance.getPortByKey('sete');
      expect(port, isNotNull);
      expect(port!.key, 'sete');
      expect(port.name, 'Sète');
    });

    test('addFavorite("sete") -> favoritePortKeys contient "sete" (pas "Sete")', () async {
      await AppSettings.addFavorite('sete');
      expect(AppSettings.favoritePortKeys.contains('sete'), isTrue);
      expect(AppSettings.favoritePortKeys.contains('Sete'), isFalse);
      expect(AppSettings.favoritePorts.length, 1);
      expect(AppSettings.favoritePorts.first.key, 'sete');
    });

    test('removeFavorite("sete") -> la cle disparait des favoris', () async {
      await AppSettings.addFavorite('sete');
      expect(AppSettings.favoritePortKeys.contains('sete'), isTrue);
      await AppSettings.removeFavorite('sete');
      expect(AppSettings.favoritePortKeys.contains('sete'), isFalse);
      expect(AppSettings.favoritePorts, isEmpty);
    });

    test('orderByFavoritesFirst reconnait Sete favori avec sa cle normalisee', () async {
      await AppSettings.addFavorite('sete');
      final withSete = [...catalog, _p('sete', 'Sete')];
      final result = svc.orderByFavoritesFirst(
        withSete,
        AppSettings.favoritePortKeys,
      );
      final keys = result.map((p) => p.key).toList();
      expect(keys.first, 'sete');
      expect(keys.where((k) => k == 'sete').length, 1);
    });

    test('addFavorite + roundtrip SharedPreferences : la cle normalisee survit', () async {
      await AppSettings.addFavorite('sete');
      await AppSettings.saveFavoritePorts(List.from(AppSettings.favoritePorts));
      expect(AppSettings.favoritePortKeys.contains('sete'), isTrue);
      expect(AppSettings.favoritePortKeys.contains('Sete'), isFalse);
      expect(AppSettings.favoritePorts.first.key, 'sete');
    });
  });

  group('Cap d Agde - cle explicite du catalogue', () {
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await SharedPreferences.getInstance();
    });

    setUp(() {
      AppSettings.favoritePorts = [];
    });

    test('PortService.getPortByKey("cap_agde") existe', () {
      final port = PortService.instance.getPortByKey('cap_agde');
      expect(port, isNotNull);
    });

    test('PortService.getPortByKey("cap_agde").key == "cap_agde"', () {
      final port = PortService.instance.getPortByKey('cap_agde');
      expect(port!.key, 'cap_agde');
    });

    test('PortService.getPortByKey("cap_agde").name == "Cap d\'Agde"', () {
      final port = PortService.instance.getPortByKey('cap_agde');
      expect(port!.name, "Cap d'Agde");
    });

    test('PortService.getPortByKey("cap_agde").url inchangee', () {
      final port = PortService.instance.getPortByKey('cap_agde');
      expect(
        port!.url,
        'https://meteofrance.com/meteo-marine/cap-d-agde/570229',
      );
    });

    test('addFavorite("cap_agde") ajoute le port avec la bonne cle', () async {
      await AppSettings.addFavorite('cap_agde');
      expect(AppSettings.favoritePortKeys.contains('cap_agde'), isTrue);
      expect(AppSettings.favoritePorts.length, 1);
      expect(AppSettings.favoritePorts.first.key, 'cap_agde');
      expect(AppSettings.favoritePorts.first.name, "Cap d'Agde");
    });
  });

  group('Selection immediate du port actif dans le picker', () {
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await SharedPreferences.getInstance();
    });

    setUp(() {
      AppSettings.favoritePorts = [];
    });

    test('saveSelectedPort synchronise selectedPortKey avant retour (await)', () async {
      AppSettings.selectedPortKey = 'a';
      await AppSettings.saveSelectedPort('b');
      expect(AppSettings.selectedPortKey, 'b');
    });

    test('Selection B -> orderByFavoritesFirst place B en tete', () async {
      AppSettings.selectedPortKey = 'a';
      await AppSettings.saveSelectedPort('b');
      final result = svc.orderByFavoritesFirst(
        catalog,
        <String>{},
        selectedPortKey: AppSettings.selectedPortKey,
      );
      expect(result.first.key, 'b');
    });

    test('Favoris + selection : B favori, selection B -> B en tete, pas de doublon', () async {
      AppSettings.selectedPortKey = 'a';
      await AppSettings.addFavorite('b');
      await AppSettings.saveSelectedPort('b');
      final result = svc.orderByFavoritesFirst(
        catalog,
        AppSettings.favoritePortKeys,
        selectedPortKey: AppSettings.selectedPortKey,
      );
      final keys = result.map((p) => p.key).toList();
      expect(keys.first, 'b');
      expect(keys.where((k) => k == 'b').length, 1);
    });

    test('Changements multiples rapides : A -> C -> D -> A', () async {
      AppSettings.selectedPortKey = 'a';
      await AppSettings.saveSelectedPort('c');
      expect(AppSettings.selectedPortKey, 'c');
      await AppSettings.saveSelectedPort('d');
      expect(AppSettings.selectedPortKey, 'd');
      await AppSettings.saveSelectedPort('a');
      expect(AppSettings.selectedPortKey, 'a');
      final result = svc.orderByFavoritesFirst(
        catalog,
        <String>{},
        selectedPortKey: AppSettings.selectedPortKey,
      );
      expect(result.first.key, 'a');
    });

    test('Selection "Aucun" : selectedPortKey = null', () async {
      AppSettings.selectedPortKey = 'a';
      await AppSettings.saveSelectedPort(null);
      expect(AppSettings.selectedPortKey, isNull);
      final result = svc.orderByFavoritesFirst(
        catalog,
        <String>{},
        selectedPortKey: null,
      );
      expect(result.map((p) => p.key).toList(), ['a', 'b', 'c', 'd', 'e', 'f']);
    });
  });

  group('Premier lancement - valeurs par defaut', () {
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await SharedPreferences.getInstance();
    });

    setUp(() async {
      AppSettings.selectedPortKey = null;
      AppSettings.favoritePorts = [];
    });

    test('Premier lancement : selectedPortKey = palavas_les_flots (defaut)', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await SharedPreferences.getInstance();
      await AppSettings.loadSettings();
      expect(AppSettings.selectedPortKey, 'palavas_les_flots');
    });

    test('Premier lancement : favoritePorts contient Palavas (defaut)', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await SharedPreferences.getInstance();
      await AppSettings.loadSettings();
      final keys = AppSettings.favoritePortKeys;
      expect(keys.contains('palavas_les_flots'), isTrue,
          reason: 'palavas_les_flots doit etre favori par defaut (catalogue PortService)');
      expect(keys.length, 1,
          reason: 'un seul favori par defaut');
    });

    test('Premier lancement : le port a les bons name/url', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await SharedPreferences.getInstance();
      await AppSettings.loadSettings();
      expect(AppSettings.favoritePorts.length, 1);
      final port = AppSettings.favoritePorts.single;
      expect(port.key, 'palavas_les_flots');
      expect(port.name, 'Palavas Les Flots');
      expect(port.url, 'https://meteofrance.com/meteo-marine/palavas-les-flots/570277');
    });
  });
}
