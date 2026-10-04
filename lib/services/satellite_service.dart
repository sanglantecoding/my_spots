import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../controllers/gps_controller.dart';
import 'gps_service.dart';
import 'dart:async';

/// Informations estimées sur un satellite (basées sur la précision)
///
/// IMPORTANT : Ces données sont estimées à partir de la précision GPS fournie
/// par Geolocator. Elles ne représentent PAS de véritables données satellites
/// matérielles (NMEA), car Geolocator n'expose pas cette information.
class SatelliteInfo {
  final int id;
  final double signalStrength;
  final String type;
  final bool used;

  SatelliteInfo({
    required this.id,
    required this.signalStrength,
    required this.type,
    required this.used,
  });
}

/// Niveau de qualité du fix GPS affiché par la vue satellites.
enum FixQuality { excellent, good, medium, poor, unknown }

/// Service pour la gestion des informations GPS et de précision
class SatelliteService {
  static StreamSubscription<Position>? _positionSubscription;
  static final List<SatelliteInfo> _satellites = [];
  static String _gnssType = 'Multi-GNSS';
  static bool _isInitialized = false;

  /// Précision horizontale actuelle en mètres (source primaire : GpsController)
  static double? _currentAccuracy;

  /// Position actuelle (mise à jour en continu par le flux)
  static Position? _currentPosition;

  /// Indique si les données sont estimées (toujours true pour Geolocator)
  static bool get isEstimated => true;

  /// Indique si le service a une souscription active au flux de position
  static bool get isListening => _positionSubscription != null;

  /// Initialise le service (appelé au démarrage de l'app).
  static Future<void> initialize() async {
    if (_positionSubscription == null) {
      _isInitialized = false;
    }
    if (_isInitialized) return;

    try {
      _currentAccuracy = GpsController.instance.currentAccuracy;
      _currentPosition = GpsController.instance.currentPosition;
      _generateEstimatedSatelliteView(_currentAccuracy);

      _positionSubscription = GpsController.instance.positionStream.listen(
        _onPositionUpdate,
      );

      _isInitialized = true;
    } catch (e) {
      _generateEstimatedSatelliteView();
      _isInitialized = true;
    }
  }

  /// Démarre l'écoute (pour clic manuel).
  ///
  /// Garantit qu'une souscription existe même après un précédent [stopSatelliteTracking].
  static Future<void> startSatelliteTracking() async {
    if (_positionSubscription == null) {
      _isInitialized = false;
    }
    await initialize();
  }

  /// Arrête le suivi et réinitialise l'état pour autoriser une réécoute ultérieure.
  static void stopSatelliteTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _isInitialized = false;
  }

  /// Traite les mises à jour de position
  static void _onPositionUpdate(Position position) {
    _currentPosition = position; // ✅ Mise à jour de la position courante
    _currentAccuracy = position.accuracy;
    _generateEstimatedSatelliteView(position.accuracy);
  }

  /// Génère une vue estimée des satellites à partir de la précision.
  ///
  /// Les données sont des estimations : ce ne sont PAS de véritables
  /// informations satellites (NMEA). Geolocator ne fournit pas ce niveau
  /// de détail ; nous visualisons donc la qualité du signal via la précision.
  static void _generateEstimatedSatelliteView([double? accuracy]) {
    final seed = DateTime.now().millisecondsSinceEpoch % 100;
    _satellites.clear();

    final displayCount = accuracy != null
        ? _estimatedSatelliteCount(accuracy)
        : 8;

    final minSatellites = displayCount < 4 ? 4 : displayCount;

    for (int i = 0; i < minSatellites; i++) {
      final signalStrength = 0.3 + (seed + i * 13) % 70 / 100.0;
      final used = signalStrength > 0.5 && i < 12;

      _satellites.add(
        SatelliteInfo(
          id: i + 1,
          signalStrength: signalStrength,
          type: _getSatelliteType(i),
          used: used,
        ),
      );
    }

    _gnssType = _getDominantGnssType();
  }

  /// Obtient la position actuelle
  static Future<Position?> getCurrentPosition() async {
    // Si le flux tourne, _currentPosition est déjà à jour grâce à _onPositionUpdate
    if (_currentPosition != null) return _currentPosition;

    try {
      _currentPosition = await GpsController.instance.getCurrentPosition();
      return _currentPosition;
    } catch (e) {
      return null;
    }
  }

  /// Précision horizontale actuelle en mètres (source : GpsController)
  static double? get currentAccuracy {
    return _currentAccuracy ?? GpsController.instance.currentAccuracy;
  }

  /// Qualité du fix GPS, DÉRIVÉE des seuils uniques de [GpsService].
  ///
  /// Plus aucun seuil local : à précision égale, cette vue affiche
  /// strictement le même verdict que le reste de l'application.
  static FixQuality get fixQuality {
    final acc = currentAccuracy;
    if (acc == null || acc <= 0) return FixQuality.unknown;
    return switch (GpsService.getGpsStatus(acc)) {
      GpsStatus.excellent => FixQuality.excellent,
      GpsStatus.good => FixQuality.good,
      GpsStatus.medium => FixQuality.medium,
      GpsStatus.poor => FixQuality.poor,
    };
  }

  /// Convertit un [FixQuality] vers son [GpsStatus] d'origine (`null` si unknown).
  static GpsStatus? _toGpsStatus(FixQuality quality) => switch (quality) {
    FixQuality.excellent => GpsStatus.excellent,
    FixQuality.good => GpsStatus.good,
    FixQuality.medium => GpsStatus.medium,
    FixQuality.poor => GpsStatus.poor,
    FixQuality.unknown => null,
  };

  /// Qualité du signal estimée (0.0 - 1.0), dérivée du statut unifié.
  static double get signalQuality {
    final acc = currentAccuracy;
    if (acc == null || acc <= 0) return 0.0;
    return switch (GpsService.getGpsStatus(acc)) {
      GpsStatus.excellent => 0.95,
      GpsStatus.good => 0.75,
      GpsStatus.medium => 0.55,
      GpsStatus.poor => acc < 50 ? 0.35 : 0.15,
    };
  }

  /// Nombre estimé de satellites visibles (basé sur la précision)
  static int get totalSatellites {
    final acc = currentAccuracy;
    if (acc == null) return _satellites.length;
    return _estimatedSatelliteCount(acc);
  }

  /// Nombre estimé de satellites utilisés dans le fix
  static int get usedSatellites {
    final total = totalSatellites;
    // ~70-80% des satellites visibles sont typiquement utilisés
    return (total * 0.75).round().clamp(0, total).toInt();
  }

  /// Type GNSS affiché
  static String get gnssType => _gnssType;

  /// Nombre de satellites affichés, dérivé du statut unifié
  /// (ancien barème local 5/10/20 m supprimé).
  static int _estimatedSatelliteCount(double accuracy) =>
      switch (GpsService.getGpsStatus(accuracy)) {
        GpsStatus.excellent => 12,
        GpsStatus.good => 10,
        GpsStatus.medium => 8,
        GpsStatus.poor => 6,
      };

  /// Type de satellite par index (estimation)
  static String _getSatelliteType(int index) {
    final types = ['GPS', 'GLONASS', 'GALILEO', 'BEIDOU'];
    return types[index % types.length];
  }

  /// Type GNSS dominant estimé
  static String _getDominantGnssType() {
    final gpsCount = _satellites.where((s) => s.type == 'GPS').length;
    final glonassCount = _satellites.where((s) => s.type == 'GLONASS').length;
    final galileoCount = _satellites.where((s) => s.type == 'GALILEO').length;
    final beidouCount = _satellites.where((s) => s.type == 'BEIDOU').length;

    if (gpsCount >= glonassCount &&
        gpsCount >= galileoCount &&
        gpsCount >= beidouCount) {
      return 'GPS';
    }
    if (glonassCount >= galileoCount && glonassCount >= beidouCount) {
      return 'GLONASS';
    }
    if (galileoCount >= beidouCount) {
      return 'GALILEO';
    }
    return 'BEIDOU';
  }

  /// Liste des satellites (vue estimée, pas des données réelles)
  static List<SatelliteInfo> get satellites => List.unmodifiable(_satellites);

  /// Description textuelle de la qualité du fix.
  /// Vocabulaire propre à la vue satellites ; le classement vient de fixQuality.
  static String getGpsStatusDescription() {
    switch (fixQuality) {
      case FixQuality.excellent:
        return 'Position excellente';
      case FixQuality.good:
        return 'Position bonne';
      case FixQuality.medium:
        return 'Précision moyenne';
      case FixQuality.poor:
        return 'Précision faible';
      case FixQuality.unknown:
        return 'Position indisponible';
    }
  }

  /// Libellé court de la qualité (vocabulaire de la vue satellites).
  static String getFixQualityLabel() {
    switch (fixQuality) {
      case FixQuality.excellent:
        return 'Excellent';
      case FixQuality.good:
        return 'Bon';
      case FixQuality.medium:
        return 'Moyen';
      case FixQuality.poor:
        return 'Faible';
      case FixQuality.unknown:
        return 'Inconnu';
    }
  }

  /// Couleur correspondant à la qualité du fix.
  static Color getGpsStatusColor() {
    final status = _toGpsStatus(fixQuality);
    if (status == null) return Colors.grey;
    return GpsService.getGpsStatusColor(status);
  }
}
