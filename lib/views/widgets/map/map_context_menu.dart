import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:my_spots/app_settings.dart';

/// Callbacks pour les actions du menu contextuel de la carte.
class MapContextMenuCallbacks {
  final Future<void> Function(LatLng point) onAddWaypoint;
  final Future<void> Function(LatLng point) onOpenOfflineZone;
  final Future<void> Function(LatLng point) onShowOfflineModeBlockingDialog;
  final void Function(LatLng point) onStartDistanceMeasurement;
  final Future<void> Function(LatLng point) onShowMushroomForecast;

  const MapContextMenuCallbacks({
    required this.onAddWaypoint,
    required this.onOpenOfflineZone,
    required this.onShowOfflineModeBlockingDialog,
    required this.onStartDistanceMeasurement,
    required this.onShowMushroomForecast,
  });
}

/// Affiche le menu contextuel (BottomSheet) au point de long-press sur la carte.
void showMapContextMenu(
  BuildContext context,
  LatLng point,
  MapContextMenuCallbacks callbacks,
) {
  final isOffline = AppSettings.offlineModeEnabled;
  final isMarine = AppSettings.mapType == MapType.marine;
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF0D1B2A),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(
              Icons.add_location_alt,
              color: Color(0xFF0D6999),
            ),
            title: const Text(
              "Ajouter un waypoint ici",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              "Lat ${point.latitude.toStringAsFixed(5)}  Lon ${point.longitude.toStringAsFixed(5)}",
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
            onTap: () {
              Navigator.pop(ctx);
              unawaited(callbacks.onAddWaypoint(point));
            },
          ),
          ListTile(
            leading: const Icon(Icons.park, color: Color(0xFF80CBC4)),
            title: const Text(
              'Prévision cèpe ici',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
            ),
            subtitle: const Text(
              'Prévision de J+0 à J+7',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
            onTap: () {
              Navigator.pop(ctx);
              unawaited(callbacks.onShowMushroomForecast(point));
            },
          ),
          ListTile(
            leading: Icon(
              Icons.crop_free,
              color: isMarine ? const Color(0xFF0D6999) : Colors.white24,
            ),
            title: Text(
              "Tracer une zone hors-ligne",
              style: TextStyle(
                color: isMarine ? Colors.white : Colors.white38,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              !isMarine
                  ? "Disponible uniquement avec la carte marine (SHOM)"
                  : isOffline
                  ? "Passez en ligne pour tracer une zone"
                  : "Definir une zone de telechargement",
              style: TextStyle(
                color: !isMarine
                    ? Colors.white38
                    : isOffline
                    ? Colors.orangeAccent
                    : Colors.white38,
                fontSize: 12,
              ),
            ),
            onTap: !isMarine
                ? null
                : () {
                    Navigator.pop(ctx);
                    if (isOffline) {
                      unawaited(callbacks.onShowOfflineModeBlockingDialog(point));
                    } else {
                      unawaited(callbacks.onOpenOfflineZone(point));
                    }
                  },
          ),
          ListTile(
            leading: const Icon(Icons.straighten, color: Color(0xFF0D6999)),
            title: const Text(
              "Mesurer une distance",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: const Text(
              "Placer deux points pour mesurer",
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
            onTap: () {
              Navigator.pop(ctx);
              callbacks.onStartDistanceMeasurement(point);
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );
}
