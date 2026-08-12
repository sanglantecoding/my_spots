import 'package:flutter/material.dart';

/// Utilitaires pour la gestion du statut GPS
class GpsStatusUtils {
  /// Obtient le libellé du statut GPS selon la précision
  static String getGpsStatusLabel(double? accuracy) {
    if (accuracy == null) return 'Inconnu';

    if (accuracy < 8) return 'Vert';
    if (accuracy < 15) return 'Jaune';
    if (accuracy < 30) return 'Orange';
    return 'Rouge';
  }

  /// Obtient la couleur du statut GPS selon le libellé
  static Color getGpsStatusColor(String? status) {
    switch (status) {
      case 'Vert':
        return Colors.green;
      case 'Jaune':
        return Colors.amber;
      case 'Orange':
        return Colors.orange;
      case 'Rouge':
        return Colors.red;
      case 'Inconnu':
        return Colors
            .grey
            .shade300; // Gris très clair pour les imports sans métadonnées
      default:
        return Colors.grey;
    }
  }

  /// Obtient l'icône du statut GPS selon le libellé
  static IconData getGpsStatusIcon(String? status) {
    switch (status) {
      case 'Vert':
      case 'Jaune':
        return Icons.gps_fixed;
      case 'Orange':
        return Icons.location_searching;
      case 'Rouge':
        return Icons.gps_off;
      case 'Inconnu':
        return Icons
            .help_outline; // Icône d'aide pour les imports sans métadonnées
      default:
        return Icons.help_outline;
    }
  }

  /// Obtient la description du statut GPS selon le libellé
  static String getGpsStatusDescription(String? status) {
    switch (status) {
      case 'Vert':
        return 'Précision excellente';
      case 'Jaune':
        return 'Précision bonne';
      case 'Orange':
        return 'Précision moyenne';
      case 'Rouge':
        return 'Précision faible';
      case 'Inconnu':
        return 'Signal inconnu (import sans métadonnées)'; // Description spécifique pour les imports
      default:
        return 'Précision inconnue';
    }
  }
}
