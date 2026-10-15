import 'package:flutter/material.dart';
import 'package:my_spots/app_settings.dart';

/// Bouton de sélection de palette pour les contrôles champignon.
class MushroomPaletteButton extends StatelessWidget {
  final MushroomPalette palette;
  final String label;
  final VoidCallback onTap;

  const MushroomPaletteButton({
    super.key,
    required this.palette,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = AppSettings.mushroomPalette == palette;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.tealAccent.withValues(alpha: 0.3)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.tealAccent : Colors.white70,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}
