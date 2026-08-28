import 'package:flutter/material.dart';
import '../services/satellite_service.dart';

/// Boîte de dialogue affichant l'état et la précision GPS
class SatelliteStatusDialog extends StatefulWidget {
  const SatelliteStatusDialog({super.key});

  @override
  State<SatelliteStatusDialog> createState() => _SatelliteStatusDialogState();
}

class _SatelliteStatusDialogState extends State<SatelliteStatusDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _animationController.forward();
    SatelliteService.startSatelliteTracking();
  }

  @override
  void dispose() {
    _animationController.dispose();
    SatelliteService.stopSatelliteTracking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0A1929),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          padding: const EdgeInsets.all(20),
          constraints: const BoxConstraints(maxHeight: 700),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                _buildEstimatedBadge(),
                const SizedBox(height: 20),
                _buildAccuracyCard(),
                const SizedBox(height: 20),
                _buildStatusOverview(),
                const SizedBox(height: 20),
                _buildSatelliteList(),
                const SizedBox(height: 20),
                _buildActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// En-tête de la boîte de dialogue
  Widget _buildHeader() {
    return Row(
      children: [
        Icon(Icons.satellite_alt, color: Colors.blueAccent, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'État et Précision GPS',
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
    );
  }

  /// Badge indiquant statut estimé
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

  /// Carte de précision horizontale (métrique de vérité)
  Widget _buildAccuracyCard() {
    final accuracy = SatelliteService.currentAccuracy;
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
                  fontSize: 44,
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
            'Qualité du signal : ${(SatelliteService.signalQuality * 100).toInt()}% — '
            '${SatelliteService.getGpsStatusDescription()}',
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
        ],
      ),
    );
  }

  /// Vue d'ensemble du statut GPS
  Widget _buildStatusOverview() {
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
            'Aucun flux NMEA natif fourni par Geolocator.',
            style: TextStyle(color: Colors.grey[500], fontSize: 11),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatusItem(
                'Satellites utilisés (est.)',
                '${SatelliteService.usedSatellites}',
                SatelliteService.getGpsStatusColor(),
              ),
              _buildStatusItem(
                'Satellites visibles (est.)',
                '${SatelliteService.totalSatellites}',
                Colors.blueAccent,
              ),
              _buildStatusItem(
                'Constellation',
                SatelliteService.gnssType,
                Colors.green,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Élément de statut individuel
  Widget _buildStatusItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: Colors.grey[400], fontSize: 11),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Liste détaillée des satellites (vue estimée)
  Widget _buildSatelliteList() {
    final satellites = SatelliteService.satellites;

    return Container(
      constraints: const BoxConstraints(maxHeight: 280),
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
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: satellites.length,
              itemBuilder: (context, index) {
                final satellite = satellites[index];
                return _buildSatelliteItem(satellite, index);
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Élément satellite individuel
  Widget _buildSatelliteItem(SatelliteInfo satellite, int index) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: satellite.used
            ? const Color(0xFF2A3F52)
            : const Color(0xFF152A3D),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: satellite.used
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          // Icône du satellite
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getSatelliteTypeColor(satellite.type),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.satellite_alt, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          // Informations
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Sat. ${satellite.id} (est.)',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _getSatelliteTypeColor(satellite.type),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        satellite.type,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      satellite.used ? 'Utilisé (est.)' : 'Non utilisé (est.)',
                      style: TextStyle(
                        color: satellite.used ? Colors.green : Colors.grey[500],
                        fontSize: 11,
                      ),
                    ),
                    const Spacer(),
                    _buildSignalBars(satellite.signalStrength),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Barres de signal pour un satellite
  Widget _buildSignalBars(double signalStrength) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (index) {
        final isActive = signalStrength > (index + 1) * 0.25;
        return Container(
          width: 3,
          height: 8 + index * 3,
          margin: const EdgeInsets.only(right: 2),
          decoration: BoxDecoration(
            color: isActive ? Colors.green : Colors.grey[600],
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }

  /// Boutons d'action
  Widget _buildActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Fermer', style: TextStyle(color: Colors.blueAccent)),
        ),
      ],
    );
  }

  /// Obtient la couleur selon le type de satellite
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
