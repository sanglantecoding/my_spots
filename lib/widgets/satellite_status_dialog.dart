import 'package:flutter/material.dart';
import '../services/satellite_service.dart';

/// Boîte de dialogue affichant l'état détaillé des satellites GPS
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
          constraints: const BoxConstraints(maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
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
            'État du GPS',
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

  /// Vue d'ensemble du statut GPS
  Widget _buildStatusOverview() {
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
              _buildStatusItem(
                'Satellites utilisés',
                '${SatelliteService.usedSatellites}',
                SatelliteService.getGpsStatusColor(),
              ),
              _buildStatusItem(
                'Satellites visibles',
                '${SatelliteService.totalSatellites}',
                Colors.blueAccent,
              ),
              _buildStatusItem(
                'Type GNSS',
                SatelliteService.gnssType,
                Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSignalStrengthIndicator(),
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
          style: TextStyle(color: Colors.grey[400], fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Indicateur de force du signal
  Widget _buildSignalStrengthIndicator() {
    final signalAccuracy = SatelliteService.signalAccuracy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Force du signal',
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text(
              '${(signalAccuracy * 100).toInt()}%',
              style: TextStyle(
                color: _getSignalColor(signalAccuracy),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: signalAccuracy,
          backgroundColor: Colors.grey[700],
          valueColor: AlwaysStoppedAnimation<Color>(
            _getSignalColor(signalAccuracy),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          SatelliteService.getGpsStatusDescription(),
          style: TextStyle(color: Colors.grey[400], fontSize: 12),
        ),
      ],
    );
  }

  /// Liste détaillée des satellites
  Widget _buildSatelliteList() {
    final satellites = SatelliteService.satellites;

    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A2F42),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
            Expanded(
              child: ListView.builder(
                itemCount: satellites.length,
                itemBuilder: (context, index) {
                  final satellite = satellites[index];
                  return _buildSatelliteItem(satellite, index);
                },
              ),
            ),
          ],
        ),
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
                      'Satellite ${satellite.id}',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
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
                      satellite.used ? 'Utilisé' : 'Non utilisé',
                      style: TextStyle(
                        color: satellite.used ? Colors.green : Colors.grey[500],
                        fontSize: 12,
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

  /// Obtient la couleur selon la force du signal
  Color _getSignalColor(double signalAccuracy) {
    if (signalAccuracy > 0.7) return Colors.green;
    if (signalAccuracy > 0.5) return Colors.amber;
    if (signalAccuracy > 0.3) return Colors.orange;
    return Colors.red;
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
