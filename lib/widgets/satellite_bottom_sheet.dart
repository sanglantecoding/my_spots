import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/satellite_service.dart';
import '../controllers/gps_controller.dart';
import 'dart:async';

/// ModalBottomSheet affichant les détails de précision GPS
class SatelliteBottomSheet extends StatefulWidget {
  const SatelliteBottomSheet({super.key});

  @override
  State<SatelliteBottomSheet> createState() => _SatelliteBottomSheetState();
}

class _SatelliteBottomSheetState extends State<SatelliteBottomSheet> {
  double? _currentAltitude;
  double? _currentAccuracy;
  StreamSubscription<Position>? _positionSubscription;

  @override
  void initState() {
    super.initState();
    SatelliteService.startSatelliteTracking();
    _startTracking();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    SatelliteService.stopSatelliteTracking();
    super.dispose();
  }

  /// Démarre le suivi altitude et précision
  void _startTracking() async {
    try {
      final position = await GpsController.instance.getCurrentPosition();
      if (position != null && mounted) {
        setState(() {
          _currentAltitude = position.altitude;
          _currentAccuracy = position.accuracy;
        });
      }

      _positionSubscription = GpsController.instance.positionStream.listen((
        Position position,
      ) {
        if (mounted) {
          setState(() {
            _currentAltitude = position.altitude;
            _currentAccuracy = position.accuracy;
          });
        }
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

          // En-tête avec badge "Statut Évalué"
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.satellite_alt,
                      color: Colors.blueAccent,
                      size: 24,
                    ),
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
                const SizedBox(height: 6),
                _buildEstimatedBadge(),
              ],
            ),
          ),

          // Contenu
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: ListView(
                children: [
                  _buildAccuracyCard(),
                  const SizedBox(height: 16),
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

  /// Badge indiquant que le statut est estimé (pas des données NMEA réelles)
  Widget _buildEstimatedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.indigo.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.indigo.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline, color: Colors.indigo[200], size: 12),
          const SizedBox(width: 6),
          Text(
            'Statut Évalué (Basé sur la précision)',
            style: TextStyle(
              color: Colors.indigo[200],
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Carte principale : précision horizontale (métrique de vérité)
  Widget _buildAccuracyCard() {
    final accuracy = _currentAccuracy ?? SatelliteService.currentAccuracy;
    final qualityLabel = SatelliteService.getFixQualityLabel();
    final qualityColor = SatelliteService.getGpsStatusColor();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            qualityColor.withValues(alpha: 0.15),
            const Color(0xFF1A2F42),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: qualityColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, color: qualityColor, size: 22),
              const SizedBox(width: 8),
              Text(
                'Précision horizontale',
                style: TextStyle(
                  color: Colors.grey[300],
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: qualityColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  qualityLabel,
                  style: TextStyle(
                    color: qualityColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                accuracy != null ? accuracy.toStringAsFixed(1) : '--',
                style: TextStyle(
                  color: qualityColor,
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'mètres',
                  style: TextStyle(color: Colors.grey[400], fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: SatelliteService.signalQuality,
              minHeight: 8,
              backgroundColor: Colors.grey[800],
              valueColor: AlwaysStoppedAnimation<Color>(qualityColor),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Qualité du signal : ${(SatelliteService.signalQuality * 100).toInt()}%',
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Estimation de la couverture GNSS',
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Données estimées à partir de la précision. '
            'Le framework Geolocator ne fournit pas de flux NMEA natif.',
            style: TextStyle(color: Colors.grey[500], fontSize: 11),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                'Satellites (est.)',
                '${SatelliteService.usedSatellites}/${SatelliteService.totalSatellites}',
                SatelliteService.getGpsStatusColor(),
              ),
              _buildStatItem(
                'Constellation',
                SatelliteService.gnssType,
                Colors.green,
              ),
              _buildStatItem(
                'Fix',
                SatelliteService.getFixQualityLabel(),
                SatelliteService.getGpsStatusColor(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            SatelliteService.getGpsStatusDescription(),
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
            textAlign: TextAlign.center,
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

  /// Liste des satellites (vue estimée)
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Row(
              children: [
                Text(
                  'Vue satellites (estimée)',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Estimation',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Visualisation qualitative basée sur la précision horizontale',
              style: TextStyle(color: Colors.grey[500], fontSize: 11),
            ),
          ),
          const SizedBox(height: 8),
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

  /// Message quand aucune donnée d'estimation n'est disponible
  Widget _buildEmptySatelliteMessage() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Icon(Icons.satellite_alt, color: Colors.grey[400], size: 48),
          const SizedBox(height: 16),
          Text(
            'Données GPS en cours de récupération',
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
