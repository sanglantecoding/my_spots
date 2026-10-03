import 'dart:convert';

import 'package:latlong2/latlong.dart';
import 'package:objectbox/objectbox.dart';

enum OfflineMapStatus { notStarted, downloading, partial, ready, failed }

@Entity()
class OfflineMap {
  @Id()
  int id = 0;

  final String uuid;
  final String name;
  final double northLat;
  final double southLat;
  final double westLng;
  final double eastLng;

  /// Polygon vertices as JSON string (null for rectangle zones)
  /// Format: [{"lat": 45.0, "lng": 2.0}, ...] in order of points
  String? polygonJson;

  int statusIndex;

  /// Message d'erreur ou d'information après le dernier téléchargement.
  /// Ex: "Interrompu : plafond de tuiles dépassé", "Échecs réseau sur 2 couche(s)".
  String? lastError;

  @Property(type: PropertyType.date)
  final DateTime createdAt;

  @Property(type: PropertyType.date)
  DateTime completedAt = DateTime.fromMillisecondsSinceEpoch(0);

  OfflineMap({
    this.id = 0,
    required this.uuid,
    required this.name,
    required this.northLat,
    required this.southLat,
    required this.westLng,
    required this.eastLng,
    this.polygonJson,
    required this.statusIndex,
    required this.createdAt,
    this.lastError,
    DateTime? completedAt,
  }) : completedAt = completedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  factory OfflineMap.create({
    required String uuid,
    required String name,
    required double northLat,
    required double southLat,
    required double westLng,
    required double eastLng,
    String? polygonJson,
  }) {
    return OfflineMap(
      uuid: uuid,
      name: name,
      northLat: northLat,
      southLat: southLat,
      westLng: westLng,
      eastLng: eastLng,
      polygonJson: polygonJson,
      statusIndex: OfflineMapStatus.notStarted.index,
      createdAt: DateTime.now(),
      lastError: null,
    );
  }

  OfflineMapStatus get status =>
      OfflineMapStatus.values[statusIndex
          .clamp(0, OfflineMapStatus.values.length - 1)
          .toInt()];

  set status(OfflineMapStatus value) {
    statusIndex = value.index;
  }

  bool get isReady => status == OfflineMapStatus.ready;
  bool get isNotStarted => status == OfflineMapStatus.notStarted;

  bool get isCompleted => completedAt.millisecondsSinceEpoch > 0;

  /// Decode polygon vertices from JSON string
  /// Returns null if polygonJson is null, invalid, or has fewer than 3 points
  List<LatLng>? get polygonPoints {
    if (polygonJson == null) return null;

    try {
      final dynamic decoded = jsonDecode(polygonJson!) as List<dynamic>;
      if (decoded.isEmpty) return null;
      final points = <LatLng>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          final lat = item['lat'];
          final lng = item['lng'];
          if (lat is num && lng is num) {
            points.add(LatLng(lat.toDouble(), lng.toDouble()));
          }
        }
      }
      // Require at least 3 points for a valid polygon
      if (points.length < 3) return null;
      return points;
    } catch (e) {
      return null;
    }
  }

  bool get hasPolygonData => polygonJson != null;

  @override
  String toString() =>
      'OfflineMap(id=$id, uuid=$uuid, name=$name, status=${status.name})';
}
