import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_spots/app_settings.dart';
import 'package:my_spots/views/widgets/map/mushroom_controls_widget.dart';

void main() {
  group('MushroomControlsWidget', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SharedPreferences.getInstance();
      AppSettings.mushroomOverlayEnabled = false;
      AppSettings.mushroomOverlayOpacity = 0.6;
    });

    testWidgets('Checkbox cochee active l\'overlay et notifie onChanged', (
      tester,
    ) async {
      var called = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MushroomControlsWidget(onChanged: () => called++),
          ),
        ),
      );
      expect(find.text('Prévision champignons'), findsOneWidget);
      final checkbox = find.byType(Checkbox);
      expect(tester.widget<Checkbox>(checkbox).value, isFalse);
      await tester.tap(checkbox);
      await tester.pumpAndSettle();
      expect(AppSettings.mushroomOverlayEnabled, isTrue);
      expect(called, equals(1));
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('Slider de transparence met a jour AppSettings', (
      tester,
    ) async {
      AppSettings.mushroomOverlayEnabled = true;
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: const MushroomControlsWidget())),
      );
      await tester.pumpAndSettle();
      final slider = find.byType(Slider);
      expect(tester.widget<Slider>(slider).value, closeTo(0.6, 0.001));
      await tester.drag(slider, const Offset(100, 0));
      await tester.pumpAndSettle();
      expect(AppSettings.mushroomOverlayOpacity, greaterThan(0.6));
    });
  });
}
