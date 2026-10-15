import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_spots/views/widgets/map/mushroom_legend_widget.dart';

void main() {
  testWidgets('legend widget renders without error', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MushroomLegendWidget())),
    );
    await tester.pumpAndSettle();

    // Find legend button
    final legendButton = find.text('Légende');
    expect(legendButton, findsOneWidget);
  });
}
