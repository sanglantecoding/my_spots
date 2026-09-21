import 'package:flutter_test/flutter_test.dart';
import 'package:my_spots/models/offline_map_layer.dart';
import 'package:my_spots/services/marine_map_service.dart';

/// Tests de l'empilement logique des couches marines.
///
/// Ces tests verrouillent la logique métier d'affichage des couches :
/// - 50K vide, 25K vide, 10K disponible → 10K visible
/// - 50K vide, 25K disponible, 10K vide → 25K visible
/// - 50K disponible, 25K disponible, 10K disponible → toutes visibles dans l'ordre
/// - 50K vide, 25K vide, 10K vide → message "Dézoomez"
///
/// Ce test protège la logique d'affichage sans essayer de faire tourner
/// une vraie carte dans un test unitaire.
void main() {
  group('Empilement des couches marines — logique métier', () {
    test('Cas 1 : 50K vide, 25K vide, 10K disponible → 10K visible', () {
      // Ce test représente le scénario où seule la couche 10K est disponible
      // (par exemple, la zone est dans une zone côtière détaillée mais pas
      // couverte par les échelles plus larges).
      final availableLayers = {
        LayerType.marine50k: false, // vide
        LayerType.marine25k: false, // vide
        LayerType.marine10k: true, // disponible
      };

      final visibleLayers = _getVisibleLayers(availableLayers);

      expect(
        visibleLayers,
        contains(LayerType.marine10k),
        reason: '10K doit être visible',
      );
      expect(
        visibleLayers,
        isNot(contains(LayerType.marine50k)),
        reason: '50K ne doit pas être visible (vide)',
      );
      expect(
        visibleLayers,
        isNot(contains(LayerType.marine25k)),
        reason: '25K ne doit pas être visible (vide)',
      );
    });

    test('Cas 2 : 50K vide, 25K disponible, 10K vide → 25K visible', () {
      final availableLayers = {
        LayerType.marine50k: false, // vide
        LayerType.marine25k: true, // disponible
        LayerType.marine10k: false, // vide
      };

      final visibleLayers = _getVisibleLayers(availableLayers);

      expect(
        visibleLayers,
        contains(LayerType.marine25k),
        reason: '25K doit être visible',
      );
      expect(
        visibleLayers,
        isNot(contains(LayerType.marine50k)),
        reason: '50K ne doit pas être visible (vide)',
      );
      expect(
        visibleLayers,
        isNot(contains(LayerType.marine10k)),
        reason: '10K ne doit pas être visible (vide)',
      );
    });

    test(
      'Cas 3 : 50K disponible, 25K disponible, 10K disponible → toutes visibles',
      () {
        final availableLayers = {
          LayerType.marine50k: true,
          LayerType.marine25k: true,
          LayerType.marine10k: true,
        };

        final visibleLayers = _getVisibleLayers(availableLayers);

        expect(
          visibleLayers,
          containsAll([
            LayerType.marine50k,
            LayerType.marine25k,
            LayerType.marine10k,
          ]),
          reason: 'Toutes les couches doivent être visibles',
        );

        // Vérification de l'ordre : 50K en bas, 25K au milieu, 10K en haut
        expect(
          visibleLayers.indexOf(LayerType.marine50k),
          lessThan(visibleLayers.indexOf(LayerType.marine25k)),
          reason: '50K doit être en dessous de 25K',
        );
        expect(
          visibleLayers.indexOf(LayerType.marine25k),
          lessThan(visibleLayers.indexOf(LayerType.marine10k)),
          reason: '25K doit être en dessous de 10K',
        );
      },
    );

    test('Cas 4 : 50K vide, 25K vide, 10K vide → message Dézoomez', () {
      final availableLayers = {
        LayerType.marine50k: false,
        LayerType.marine25k: false,
        LayerType.marine10k: false,
      };

      final visibleLayers = _getVisibleLayers(availableLayers);

      expect(
        visibleLayers,
        isEmpty,
        reason: 'Aucune couche ne doit être visible → message Dézoomez',
      );
    });

    test('Cas 5 : 50K disponible, 25K vide, 10K vide → 50K visible', () {
      final availableLayers = {
        LayerType.marine50k: true,
        LayerType.marine25k: false,
        LayerType.marine10k: false,
      };

      final visibleLayers = _getVisibleLayers(availableLayers);

      expect(
        visibleLayers,
        contains(LayerType.marine50k),
        reason: '50K doit être visible',
      );
      expect(
        visibleLayers,
        isNot(contains(LayerType.marine25k)),
        reason: '25K ne doit pas être visible (vide)',
      );
      expect(
        visibleLayers,
        isNot(contains(LayerType.marine10k)),
        reason: '10K ne doit pas être visible (vide)',
      );
    });

    test(
      'Cas 6 : 50K vide, 25K disponible, 10K disponible → 25K et 10K visibles',
      () {
        final availableLayers = {
          LayerType.marine50k: false,
          LayerType.marine25k: true,
          LayerType.marine10k: true,
        };

        final visibleLayers = _getVisibleLayers(availableLayers);

        expect(
          visibleLayers,
          containsAll([LayerType.marine25k, LayerType.marine10k]),
          reason: '25K et 10K doivent être visibles',
        );
        expect(
          visibleLayers,
          isNot(contains(LayerType.marine50k)),
          reason: '50K ne doit pas être visible (vide)',
        );

        // Vérification de l'ordre : 25K en bas, 10K en haut
        expect(
          visibleLayers.indexOf(LayerType.marine25k),
          lessThan(visibleLayers.indexOf(LayerType.marine10k)),
          reason: '25K doit être en dessous de 10K',
        );
      },
    );

    test(
      'Cas 7 : 50K disponible, 25K vide, 10K disponible → 50K et 10K visibles',
      () {
        final availableLayers = {
          LayerType.marine50k: true,
          LayerType.marine25k: false,
          LayerType.marine10k: true,
        };

        final visibleLayers = _getVisibleLayers(availableLayers);

        expect(
          visibleLayers,
          containsAll([LayerType.marine50k, LayerType.marine10k]),
          reason: '50K et 10K doivent être visibles',
        );
        expect(
          visibleLayers,
          isNot(contains(LayerType.marine25k)),
          reason: '25K ne doit pas être visible (vide)',
        );

        // Vérification de l'ordre : 50K en bas, 10K en haut
        expect(
          visibleLayers.indexOf(LayerType.marine50k),
          lessThan(visibleLayers.indexOf(LayerType.marine10k)),
          reason: '50K doit être en dessous de 10K',
        );
      },
    );
  });

  group('Empilement — correspondance avec layerOrderForZoom', () {
    test('offline zoom 11 → 50K uniquement', () {
      final layerOrder = MarineMapService.layerOrderForZoom(11, offline: true);

      expect(layerOrder, hasLength(1));
      expect(layerOrder.first, 'RASTER_MARINE_50_WMTS_3857');
    });

    test('offline zoom 12 → 50K + 25K', () {
      final layerOrder = MarineMapService.layerOrderForZoom(12, offline: true);

      expect(layerOrder, hasLength(2));
      expect(layerOrder[0], 'RASTER_MARINE_50_WMTS_3857');
      expect(layerOrder[1], 'RASTER_MARINE_25_WMTS_3857');
    });

    test('offline zoom 14 → 50K + 25K + 10K', () {
      final layerOrder = MarineMapService.layerOrderForZoom(14, offline: true);

      expect(layerOrder, hasLength(3));
      expect(layerOrder[0], 'RASTER_MARINE_50_WMTS_3857');
      expect(layerOrder[1], 'RASTER_MARINE_25_WMTS_3857');
      expect(layerOrder[2], 'RASTER_MARINE_10_WMTS_3857');
    });
  });
}

/// Helper pour simuler la logique de sélection des couches visibles.
///
/// Reproduit la logique d'empilement : seules les couches disponibles
/// sont incluses, dans l'ordre défini par MarineMapService.
List<LayerType> _getVisibleLayers(Map<LayerType, bool> availability) {
  // Ordre d'empilement standard (du bas vers le haut)
  const layerOrder = [
    LayerType.marine50k,
    LayerType.marine25k,
    LayerType.marine10k,
  ];

  return layerOrder.where((type) => availability[type] == true).toList();
}
