import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/satellite_service.dart';
import 'dart:async';

/// ModalBottomSheet affichant les détails satellites et GPS
class SatelliteBottomSheet extends StatefulWidget {
  const SatelliteBottomSheet({super.key});

  @override
  State<SatelliteBottomSheet> createState() => _SatelliteBottomSheetState();
}

class _SatelliteBottomSheetState extends State<SatelliteBottomSheet> {
  double? _currentAltitude;
  StreamSubscription<Position>? _positionSubscription;

  @override
  void initState() {
    super.initState();
    SatelliteService.startSatelliteTracking();
    _startAltitudeTracking();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    SatelliteService.stopSatelliteTracking();
    super.dispose();
  }

  /// Démarre le suivi de l'altitude
  void _startAltitudeTracking() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      setState(() {
        _currentAltitude = position.altitude;
      });

      _positionSubscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 10,
            ),
          ).listen((Position position) {
            setState(() {
              _currentAltitude = position.altitude;
            });
          });
    } catch (e) {
      // Erreur silencieuse si GPS indisponible
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0A1929),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          // Barre de défilement
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // En-tête
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.satellite_alt, color: Colors.blueAccent, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Détails GPS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, color: Colors.grey[400]),
                ),
              ],
            ),
          ),

          // Contenu
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: ListView(
                children: [
                  _buildOverviewCard(),
                  const SizedBox(height: 16),
                  _buildAltitudeCard(),
                  const SizedBox(height: 16),
                  _buildSatelliteList(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Carte de vue d'ensemble
  Widget _buildOverviewCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2F42),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                'Satellites',
                '${SatelliteService.usedSatellites}/${SatelliteService.totalSatellites}',
                SatelliteService.getGpsStatusColor(),
              ),
              _buildStatItem(
                'Type GNSS',
                SatelliteService.gnssType,
                Colors.green,
              ),
              _buildStatItem(
                'Signal',
                '${(SatelliteService.signalAccuracy * 100).toInt()}%',
                _getSignalColor(SatelliteService.signalAccuracy),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: SatelliteService.signalAccuracy,
            backgroundColor: Colors.grey[700],
            valueColor: AlwaysStoppedAnimation<Color>(
              _getSignalColor(SatelliteService.signalAccuracy),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            SatelliteService.getGpsStatusDescription(),
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
        ],
      ),
    );
  }

  /// Carte d'altitude
  Widget _buildAltitudeCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2F42),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.height, color: Colors.blueAccent, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Altitude',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  _currentAltitude != null
                      ? '${_currentAltitude!.toStringAsFixed(1)} m'
                      : 'Non disponible',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Élément statistique
  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
      ],
    );
  }

  /// Liste des satellites
  Widget _buildSatelliteList() {
    final satellites = SatelliteService.satellites;

    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2F42),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Satellites détectés',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Flexible(
            child: satellites.isEmpty
                ? _buildEmptySatelliteMessage()
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: satellites.length,
                    itemBuilder: (context, index) {
                      final satellite = satellites[index];
                      return _buildSatelliteItem(satellite);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// Message quand aucun satellite n'est détecté
  Widget _buildEmptySatelliteMessage() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Icon(Icons.satellite_alt, color: Colors.grey[400], size: 48),
          const SizedBox(height: 16),
          Text(
            'Données satellites en cours de récupération\nou restreintes par le système',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[400], fontSize: 14),
          ),
          const SizedBox(height: 16),
          _buildFallbackInfo(),
        ],
      ),
    );
  }

  /// Informations de fallback quand les satellites ne sont pas disponibles
  Widget _buildFallbackInfo() {
    return FutureBuilder<Position?>(
      future: SatelliteService.getCurrentPosition(),
      builder: (context, snapshot) {
        final position = snapshot.data;

        if (position == null) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Impossible d\'obtenir la position actuelle',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A2F42),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Détails techniques de la position',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _buildFallbackStatItem(
                'Précision',
                '${position.accuracy.toStringAsFixed(1)} m',
                Colors.green,
              ),
              _buildFallbackStatItem(
                'Altitude',
                '${position.altitude.toStringAsFixed(1)} m',
                Colors.blue,
              ),
              _buildFallbackStatItem(
                'Vitesse',
                '${(position.speed * 3.6).toStringAsFixed(1)} km/h',
                Colors.orange,
              ),
              _buildFallbackStatItem('Source', 'GPS', Colors.purple),
            ],
          ),
        );
      },
    );
  }

  /// Élément statistique pour le fallback
  Widget _buildFallbackStatItem(String label, String value, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Élément satellite
  Widget _buildSatelliteItem(SatelliteInfo satellite) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: satellite.used
            ? const Color(0xFF2A3F52)
            : const Color(0xFF152A3D),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: _getSatelliteTypeColor(satellite.type),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.satellite_alt, color: Colors.white, size: 14),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Sat ${satellite.id} (${satellite.type})',
              style: TextStyle(
                color: satellite.used ? Colors.white : Colors.grey[500],
                fontSize: 12,
              ),
            ),
          ),
          _buildSignalBars(satellite.signalStrength),
        ],
      ),
    );
  }

  /// Barres de signal
  Widget _buildSignalBars(double signalStrength) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (index) {
        final isActive = signalStrength > (index + 1) * 0.25;
        return Container(
          width: 2,
          height: 6 + index * 2,
          margin: const EdgeInsets.only(right: 1),
          decoration: BoxDecoration(
            color: isActive ? Colors.green : Colors.grey[600],
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }

  /// Couleur du signal
  Color _getSignalColor(double signalAccuracy) {
    if (signalAccuracy > 0.7) return Colors.green;
    if (signalAccuracy > 0.5) return Colors.amber;
    if (signalAccuracy > 0.3) return Colors.orange;
    return Colors.red;
  }

  /// Couleur du type de satellite
  Color _getSatelliteTypeColor(String type) {
    switch (type) {
      case 'GPS':
        return Colors.blue;
      case 'GLONASS':
        return Colors.red;
      case 'GALILEO':
        return Colors.green;
      case 'BEIDOU':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
