import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:my_spots/app_settings.dart';
import 'package:my_spots/models/mushroom/forest_data.dart';
import 'package:my_spots/services/mushroom/forest_service.dart';
import 'package:path_provider/path_provider.dart';

/// Interroge la couche formations végétales de la BD Forêt V2 de l'IGN.
class IgnBdForetForestService implements ForestService {
  IgnBdForetForestService({
    http.Client? client,
    Directory? cacheDirectory,
    Uri? endpoint,
    this.timeout = const Duration(seconds: 25),
  }) : _client = client ?? http.Client(),
       _cacheDirectory = cacheDirectory,
       endpoint = endpoint ?? defaultEndpoint;

  static const layerName = 'LANDCOVER.FORESTINVENTORY.V2:formation_vegetale';
  static const cacheTtl = Duration(days: 90);
  static final Uri defaultEndpoint = Uri.https('data.geopf.fr', '/wfs/ows');

  final http.Client _client;
  final Directory? _cacheDirectory;
  final Uri endpoint;
  final Duration timeout;
  final Map<String, _CacheEntry> _memory = {};
  final Map<String, Future<ForestData>> _inFlight = {};

  @override
  Future<ForestData> getForestData({
    required double lat,
    required double lng,
  }) async {
    final key = _key(lat, lng);
    final cached = await _readCache(key, lat, lng);
    if (cached != null) return cached;
    if (AppSettings.offlineModeEnabled) return _unknown(lat, lng);
    final pending = _inFlight[key];
    if (pending != null) return pending;
    final request = _fetch(lat, lng, key);
    _inFlight[key] = request;
    try {
      return await request;
    } finally {
      if (identical(_inFlight[key], request)) _inFlight.remove(key);
    }
  }

  Future<ForestData?> _readCache(String key, double lat, double lng) async {
    final entry = _memory[key];
    if (entry != null && DateTime.now().difference(entry.savedAt) <= cacheTtl) {
      return entry.data.copyAt(lat, lng);
    }
    _memory.remove(key);
    try {
      final file = File(
        '${(await _directory()).path}${Platform.pathSeparator}$key.json',
      );
      if (!await file.exists()) return null;
      final modified = await file.lastModified();
      if (DateTime.now().difference(modified) > cacheTtl) {
        await file.delete();
        return null;
      }
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return null;
      final data = _fromJson(decoded, lat, lng);
      _memory[key] = _CacheEntry(data, modified);
      return data;
    } catch (_) {
      return null;
    }
  }

  Future<ForestData> _fetch(double lat, double lng, String key) async {
    try {
      final response = await _client
          .get(_pointQuery(lat, lng))
          .timeout(timeout);
      if (response.statusCode != 200) return _unknown(lat, lng);
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> || decoded['features'] is! List) {
        return _unknown(lat, lng);
      }
      final result = parseFeatureCollection(decoded, lat: lat, lng: lng);
      await _writeCache(key, result);
      return result;
    } catch (_) {
      return _unknown(lat, lng);
    }
  }

  /// Parse les propriétés GeoJSON. Une collection valide vide reste inconnue:
  /// la BD Forêt V2 n'est ni exhaustive ni contemporaine partout.
  static ForestData parseFeatureCollection(
    Map<String, dynamic> collection, {
    required double lat,
    required double lng,
  }) {
    final rawFeatures = collection['features'];
    if (rawFeatures is! List) return _unknown(lat, lng);
    final classified = <_Formation>[];
    for (final raw in rawFeatures) {
      if (raw is! Map) continue;
      final properties = raw['properties'];
      if (properties is! Map) continue;
      final props = properties.map((key, value) => MapEntry('$key', value));
      final formation = _classify(props);
      if (formation != null) classified.add(formation);
    }
    final forestItems = classified.where((item) => item.isForest).toList();
    final nonForestItems = classified.where((item) => !item.isForest).toList();
    final forest = forestItems.isEmpty ? null : forestItems.first;
    final nonForest = nonForestItems.isEmpty ? null : nonForestItems.first;
    return ForestData(
      latitude: lat,
      longitude: lng,
      isForest: forest != null
          ? true
          : nonForest != null
          ? false
          : null,
      forestType: forest?.forestType,
      canopyClass: forest?.canopyClass,
      treeDensity: null,
      canopyCover: null,
      source: 'ign_bdforet_v2',
    );
  }

  static _Formation? _classify(Map<String, dynamic> properties) {
    final tfv = '${properties['tfv'] ?? ''}'.trim().toLowerCase();
    final code = '${properties['code_tfv'] ?? ''}'.trim().toUpperCase();
    final essence = '${properties['essence'] ?? ''}'.trim().toLowerCase();

    // Nomenclature officielle : FF = forêt fermée, FO = forêt ouverte.
    // LA4/LA6 (landes/herbacées) sont explicitement non forestières. Les
    // autres catégories, dont les peupleraies, restent inconnues.
    final closed = code.startsWith('FF') || tfv.startsWith('forêt fermée');
    final open = code.startsWith('FO') || tfv.startsWith('forêt ouverte');
    if (closed || open) {
      String? type;
      if (code.startsWith('FF1') ||
          code.startsWith('FO1') ||
          essence.contains('feuillu')) {
        type = 'feuillu';
      } else if (code.startsWith('FF2') ||
          code.startsWith('FO2') ||
          essence.contains('conif')) {
        type = 'conifère';
      } else if (code.startsWith('FF3') ||
          code.startsWith('FO3') ||
          essence.contains('mixte')) {
        type = 'mixte';
      }
      return _Formation(true, type, closed ? 'fermée' : 'ouverte');
    }
    if (code.startsWith('LA4') ||
        code.startsWith('LA6') ||
        tfv.contains('lande') ||
        tfv.contains('formation herbacée')) {
      return const _Formation(false, null, null);
    }
    return null;
  }

  Uri _pointQuery(double lat, double lng) {
    // WFS 2.0 EPSG:4326 uses latitude, longitude axis order.
    final filter =
        '<fes:Filter xmlns:fes="http://www.opengis.net/fes/2.0" '
        'xmlns:gml="http://www.opengis.net/gml/3.2"><fes:Intersects>'
        '<fes:ValueReference>geom</fes:ValueReference><gml:Point '
        'srsName="urn:ogc:def:crs:EPSG::4326"><gml:pos>$lat $lng</gml:pos>'
        '</gml:Point></fes:Intersects></fes:Filter>';
    return endpoint.replace(
      queryParameters: {
        'SERVICE': 'WFS',
        'VERSION': '2.0.0',
        'REQUEST': 'GetFeature',
        'TYPENAMES': layerName,
        'OUTPUTFORMAT': 'application/json',
        'SRSNAME': 'urn:ogc:def:crs:EPSG::4326',
        'COUNT': '10',
        'FILTER': filter,
      },
    );
  }

  Future<void> _writeCache(String key, ForestData data) async {
    try {
      final directory = await _directory();
      final file = File('${directory.path}${Platform.pathSeparator}$key.json');
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(jsonEncode(_toJson(data)), flush: true);
      if (await file.exists()) await file.delete();
      await temp.rename(file.path);
      _memory[key] = _CacheEntry(data, DateTime.now());
    } catch (_) {
      // Une indisponibilité du disque ne rend pas la réponse réseau inutilisable.
    }
  }

  Future<Directory> _directory() async {
    final directory =
        _cacheDirectory ??
        Directory(
          '${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}mushroom_ign_bd_foret',
        );
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  static String _key(double lat, double lng) =>
      '${lat.toStringAsFixed(3).replaceAll('-', 'm')}_${lng.toStringAsFixed(3).replaceAll('-', 'm')}';

  static Map<String, dynamic> _toJson(ForestData data) => {
    'isForest': data.isForest,
    'forestType': data.forestType,
    'canopyClass': data.canopyClass,
    'source': data.source,
  };

  static ForestData _fromJson(
    Map<String, dynamic> json,
    double lat,
    double lng,
  ) => ForestData(
    latitude: lat,
    longitude: lng,
    isForest: json['isForest'] as bool?,
    forestType: json['forestType'] as String?,
    canopyClass: json['canopyClass'] as String?,
    treeDensity: null,
    canopyCover: null,
    source: json['source'] as String?,
  );

  static ForestData _unknown(double lat, double lng) => ForestData(
    latitude: lat,
    longitude: lng,
    isForest: null,
    forestType: null,
    canopyClass: null,
    treeDensity: null,
    canopyCover: null,
    source: null,
  );
}

class CompositeForestService implements ForestService {
  const CompositeForestService({required this.bdForet, required this.overpass});
  final ForestService bdForet;
  final ForestService overpass;

  @override
  Future<ForestData> getForestData({
    required double lat,
    required double lng,
  }) async {
    final results = await Future.wait([
      bdForet
          .getForestData(lat: lat, lng: lng)
          .catchError((_) => IgnBdForetForestService._unknown(lat, lng)),
      overpass
          .getForestData(lat: lat, lng: lng)
          .catchError((_) => IgnBdForetForestService._unknown(lat, lng)),
    ]);
    final bd = results[0];
    final osm = results[1];
    final isForest = bd.isForest == true || osm.isForest == true
        ? true
        : bd.isForest == false && osm.isForest != true
        ? false
        : null;
    final source = <String>{
      if (bd.source != null && bd.source != 'unknown') bd.source!,
      if (osm.source != null && osm.source != 'unknown') osm.source!,
    };
    return ForestData(
      latitude: lat,
      longitude: lng,
      isForest: isForest,
      forestType:
          bd.forestType ?? (osm.isForest == true ? osm.forestType : null),
      canopyClass: bd.canopyClass,
      treeDensity: null,
      canopyCover: null,
      landCover: osm.landCover,
      forestAreasInTile: osm.forestAreasInTile,
      nearestForestDistanceMeters: osm.nearestForestDistanceMeters,
      source: source.isEmpty ? null : source.join('+'),
    );
  }
}

class _Formation {
  const _Formation(this.isForest, this.forestType, this.canopyClass);
  final bool isForest;
  final String? forestType;
  final String? canopyClass;
}

class _CacheEntry {
  const _CacheEntry(this.data, this.savedAt);
  final ForestData data;
  final DateTime savedAt;
}

extension on ForestData {
  ForestData copyAt(double lat, double lng) => ForestData(
    latitude: lat,
    longitude: lng,
    isForest: isForest,
    forestType: forestType,
    canopyClass: canopyClass,
    treeDensity: treeDensity,
    canopyCover: canopyCover,
    landCover: landCover,
    source: source,
  );
}
