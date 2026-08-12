import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';

/// Service pour la gestion des permissions de localisation
class LocationPermissionService {
  /// Vérifie et demande les permissions de localisation
  static Future<LocationPermissionResult> requestLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Vérifier si le service GPS est activé
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationPermissionResult(
        status: LocationStatus.serviceDisabled,
        message: 'GPS DÉSACTIVÉ',
        color: Colors.red,
      );
    }

    // Vérifier les permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return LocationPermissionResult(
          status: LocationStatus.denied,
          message: 'PERMISSION REFUSÉE',
          color: Colors.red,
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return LocationPermissionResult(
        status: LocationStatus.deniedForever,
        message: 'PERMISSION REFUSÉE',
        color: Colors.red,
      );
    }

    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      return LocationPermissionResult(
        status: LocationStatus.granted,
        message: 'GPS OK',
        color: Colors.green,
      );
    }

    return LocationPermissionResult(
      status: LocationStatus.unknown,
      message: 'ERREUR INCONNUE',
      color: Colors.grey,
    );
  }
}

/// Résultat de la demande de permission
class LocationPermissionResult {
  final LocationStatus status;
  final String message;
  final Color color;

  LocationPermissionResult({
    required this.status,
    required this.message,
    required this.color,
  });
}

/// Statuts de permission possibles
enum LocationStatus {
  granted,
  denied,
  deniedForever,
  serviceDisabled,
  unknown,
}
