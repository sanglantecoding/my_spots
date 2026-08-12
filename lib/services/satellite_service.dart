import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

/// Informations sur un satellite
class SatelliteInfo {
  final int id;
  final double signalStrength; // 0.0 à 1.0
  final String type; // GPS, GLONASS, GALILEO, etc.
  final bool used;

  SatelliteInfo({
    required this.id,
    required this.signalStrength,
    required this.type,
    required this.used,
  });
}

/// Service pour la gestion des informations satellites GPS
class SatelliteService {
  static StreamSubscription<Position>? _positionSubscription;
  static final List<SatelliteInfo> _satellites = [];
  static String _gnssType = 'GPS';
  static int _totalSatellites = 0;
  static int _usedSatellites = 0;
  static bool _isInitialized = false;

  /// Initialise le service des satellites (appelé au démarrage de l'app)
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Note: Geolocator ne fournit pas directement les infos satellites
      // Nous utilisons des données réalistes basées sur la précision actuelle
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      _generateSimulatedSatellites(position.accuracy);

      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Mise à jour tous les 10m
        ),
      ).listen(_onPositionUpdate);

      _isInitialized = true;
    } catch (e) {
      // En cas d'erreur, nous utilisons des données simulées
      _generateSimulatedSatellites();
      _isInitialized = true;
    }
  }

  /// Démarre l'écoute des informations satellites (pour clic manuel)
  static Future<void> startSatelliteTracking() async {
    await initialize();
  }

  /// Arrête le suivi des satellites
  static void stopSatelliteTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  /// Traite les mises à jour de position
  static void _onPositionUpdate(Position position) {
    // Génère des données satellites simulées basées sur la précision
    _generateSimulatedSatellites(position.accuracy);
  }

  /// Position actuelle pour le fallback
  static Position? _currentPosition;

  /// Génère des données satellites simulées réalistes
  static void _generateSimulatedSatellites([double? accuracy]) {
    final random = DateTime.now().millisecondsSinceEpoch % 100;
    _satellites.clear();

    // Simulation basée sur la précision GPS
    final baseSatellites = accuracy != null
        ? _calculateSatelliteCount(accuracy)
        : 8;

    // Éviter les listes vides : garantir au minimum 4 satellites
    final minSatellites = baseSatellites < 4 ? 4 : baseSatellites;

    for (int i = 0; i < minSatellites; i++) {
      final signalStrength = 0.3 + (random + i * 13) % 70 / 100.0;
      final used = signalStrength > 0.5 && i < 12; // Seuils réalistes

      _satellites.add(
        SatelliteInfo(
          id: i + 1,
          signalStrength: signalStrength,
          type: _getSatelliteType(i),
          used: used,
        ),
      );
    }

    _totalSatellites = _satellites.length;
    _usedSatellites = _satellites.where((s) => s.used).length;
    _gnssType = _getDominantGnssType();
  }

  /// Obtient la position actuelle pour le fallback
  static Future<Position?> getCurrentPosition() async {
    if (_currentPosition != null) return _currentPosition;

    try {
      _currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      return _currentPosition;
    } catch (e) {
      return null;
    }
  }

  /// Calcule le nombre de satellites selon la précision
  static int _calculateSatelliteCount(double accuracy) {
    if (accuracy < 5) return 12; // Excellent : 12 satellites
    if (accuracy < 10) return 10; // Bon : 10 satellites
    if (accuracy < 20) return 8; // Moyen : 8 satellites
    return 6; // Faible : 6 satellites minimum
  }

  /// Détermine le type de satellite selon l'index
  static String _getSatelliteType(int index) {
    final types = ['GPS', 'GLONASS', 'GALILEO', 'BEIDOU'];
    return types[index % types.length];
  }

  /// Détermine le type GNSS dominant
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

  /// Obtient la liste des satellites
  static List<SatelliteInfo> get satellites => List.unmodifiable(_satellites);

  /// Obtient le nombre total de satellites
  static int get totalSatellites => _totalSatellites;

  /// Obtient le nombre de satellites utilisés
  static int get usedSatellites => _usedSatellites;

  /// Obtient le type GNSS dominant
  static String get gnssType => _gnssType;

  /// Obtient la précision du signal en pourcentage
  static double get signalAccuracy {
    if (_satellites.isEmpty) return 0.0;
    final totalSignal = _satellites
        .where((s) => s.used)
        .map((s) => s.signalStrength)
        .fold(0.0, (a, b) => a + b);
    return _usedSatellites > 0 ? totalSignal / _usedSatellites : 0.0;
  }

  /// Obtient une description textuelle de l'état GPS
  static String getGpsStatusDescription() {
    if (_usedSatellites == 0) return 'Aucun satellite utilisé';
    if (_usedSatellites < 4) return 'Position imprécise';
    if (_usedSatellites < 6) return 'Position correcte';
    if (_usedSatellites < 8) return 'Position bonne';
    return 'Position excellente';
  }

  /// Obtient la couleur correspondant à l'état
  static Color getGpsStatusColor() {
    if (_usedSatellites < 4) return Colors.red;
    if (_usedSatellites < 6) return Colors.orange;
    if (_usedSatellites < 8) return Colors.amber;
    return Colors.green;
  }
}
