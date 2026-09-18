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
  }) {
    return OfflineMap(
      uuid: uuid,
      name: name,
      northLat: northLat,
      southLat: southLat,
      westLng: westLng,
      eastLng: eastLng,
      statusIndex: OfflineMapStatus.notStarted.index,
      createdAt: DateTime.now(),
      lastError: null,
    );
  }

  OfflineMapStatus get status =>
      OfflineMapStatus.values[statusIndex.clamp(
        0,
        OfflineMapStatus.values.length - 1,
      )];

  set status(OfflineMapStatus value) {
    statusIndex = value.index;
  }

  bool get isReady => status == OfflineMapStatus.ready;
  bool get isNotStarted => status == OfflineMapStatus.notStarted;

  bool get isCompleted => completedAt.millisecondsSinceEpoch > 0;

  void markCompleted() {
    completedAt = DateTime.now();
    status = OfflineMapStatus.ready;
  }

  @override
  String toString() =>
      'OfflineMap(id=$id, uuid=$uuid, name=$name, status=${status.name})';
}
