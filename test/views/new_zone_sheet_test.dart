// Unit + widget tests for NewZoneSheet — the bottom sheet that collects the
// zone name before the user draws the rectangle.
//
// Verifies:
// - The sheet no longer exposes manual layer checkboxes (the layer set is
//   auto-resolved from the zone bounds, see ZoneConfig.defaultLayersForBounds).
// - defaultLayersForBounds includes marine layers everywhere.
// - defaultLayersForBounds adds LiDAR only when the bounds intersect a known
//   LiDAR region.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:my_spots/models/offline_map_layer.dart';
import 'package:my_spots/views/widgets/offline_maps/new_zone_sheet.dart';

void main() {
  group('ZoneConfig.defaultLayersForBounds', () {
    test('always includes marine layers (50K/25K/10K)', () {
      // Inland France — no LiDAR region, but marine layers are still added.
      final inland = LatLngBounds(
        LatLng(48.5, 2.0), // south
        LatLng(49.0, 2.5), // north
      );
      final layers = ZoneConfig.defaultLayersForBounds(inland);
      expect(layers, containsAll([
        LayerType.marine50k,
        LayerType.marine25k,
        LayerType.marine10k,
      ]));
    });

    test('does not include LiDAR when bounds are inland (no region)', () {
      // Auvergne — landlocked, no LiDAR region in the catalog.
      final landlocked = LatLngBounds(
        LatLng(45.5, 2.5),
        LatLng(46.0, 3.2),
      );
      final layers = ZoneConfig.defaultLayersForBounds(landlocked);
      expect(layers, isNot(contains(LayerType.lidarLitto3d)));
    });

    test('includes LiDAR layers when bounds intersect a LiDAR region', () {
      // South Brittany — covered by the Bretagne LiDAR region.
      final bretagne = LatLngBounds(
        LatLng(47.0, -3.5),
        LatLng(47.8, -2.0),
      );
      final layers = ZoneConfig.defaultLayersForBounds(bretagne);
      expect(layers, contains(LayerType.lidarLitto3d));
    });

    test('includes LiDAR layers when bounds intersect Occitanie', () {
      final occitanie = LatLngBounds(
        LatLng(43.0, 3.0),
        LatLng(43.5, 4.0),
      );
      final layers = ZoneConfig.defaultLayersForBounds(occitanie);
      expect(layers, contains(LayerType.lidarLitto3d));
    });
  });

  group('ZoneConfig.withLayers', () {
    test('replaces the layers list with the given one', () {
      const initial = ZoneConfig(name: 'Test', layers: []);
      final updated = initial.withLayers([LayerType.marine50k]);
      expect(updated.name, 'Test');
      expect(updated.layers, [LayerType.marine50k]);
    });
  });

  group('NewZoneSheet widget', () {
    testWidgets('no longer exposes manual layer checkboxes', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                await showNewZoneSheet(ctx);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // The sheet should NOT have any CheckboxListTile.
      expect(find.byType(CheckboxListTile), findsNothing);

      // The informative notice should mention automatic download.
      expect(find.textContaining('automatiquement'), findsOneWidget);
    });

    testWidgets('returns a ZoneConfig with empty layers (resolved later)',
        (tester) async {
      ZoneConfig? captured;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                captured = await showNewZoneSheet(ctx);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'Ma zone');
      await tester.tap(find.text('Suivant : Tracer la zone sur la carte'));
      await tester.pumpAndSettle();

      expect(captured, isNotNull);
      expect(captured!.name, 'Ma zone');
      // Empty list — resolved by the caller via defaultLayersForBounds.
      expect(captured!.layers, isEmpty);
    });

    testWidgets('rejects empty name and shows validation error',
        (tester) async {
      ZoneConfig? captured;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                captured = await showNewZoneSheet(ctx);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Submit without entering a name.
      await tester.tap(find.text('Suivant : Tracer la zone sur la carte'));
      await tester.pumpAndSettle();

      expect(captured, isNull);
      expect(find.text('Obligatoire'), findsOneWidget);
    });
  });
}