import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Boîte de dialogue affichée quand l'utilisateur tente de tracer une
/// zone hors-ligne alors que le mode hors-ligne est actif.
Future<bool?> showOfflineModeBlockingDialog(
  BuildContext context,
  LatLng point,
) async {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: const Color(0xFF1A2F42),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.cloud_off, color: Colors.orangeAccent, size: 28),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Mode hors-ligne actif',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      content: const Text(
        'Le tracé d\'une zone hors-ligne nécessite une connexion internet '
        '(téléchargement des tuiles SHOM). Passez en mode en ligne pour '
        'continuer.',
        style: TextStyle(color: Colors.white70, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Annuler', style: TextStyle(color: Colors.white54)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text(
            'Passer en ligne',
            style: TextStyle(
              color: Colors.greenAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );
}
