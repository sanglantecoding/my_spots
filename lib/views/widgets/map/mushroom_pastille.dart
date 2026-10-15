import 'package:flutter/material.dart';
import 'package:my_spots/models/mushroom/habitat_status.dart';
import 'package:my_spots/views/widgets/map/mushroom_color_utils.dart';

/// Badge circulaire affichant l'indice de prévision champignon.
/// Utilisée dans la liste du panneau et comme marqueur sur la carte.
class MushroomIndexBadge extends StatelessWidget {
  final int index;
  final HabitatStatus habitat;
  final double size;
  final VoidCallback? onTap;

  const MushroomIndexBadge({
    super.key,
    required this.index,
    required this.habitat,
    this.size = 24,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = indexToGradientColor(index);
    final isExcluded = habitat == HabitatStatus.excluded;
    final displayColor = isExcluded ? Colors.grey : color;
    final displayText = isExcluded ? '–' : index.toString();

    Widget child = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: displayColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Center(
        child: Text(
          displayText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );

    if (onTap != null) {
      child = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: child,
      );
    }

    return child;
  }
}

/// Alias pour compatibilité (à remplacer par MushroomIndexBadge).
@Deprecated('Use MushroomIndexBadge instead')
typedef MushroomPastille = MushroomIndexBadge;
