import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cricket_scorer/shared/widgets/neon_ball_orbit_loader.dart';

void main() {
  testWidgets('NeonBallOrbitLoader renders successfully', (WidgetTester tester) async {
    // Build the NeonBallOrbitLoader inside a MaterialApp
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: NeonBallOrbitLoader(
            loadingText: "TESTING LOADER...",
          ),
        ),
      ),
    );

    // Verify loader texts are displayed
    expect(find.text('CRICUP'), findsOneWidget);
    expect(find.text('TESTING LOADER...'), findsOneWidget);
    expect(find.text('Please wait a moment...'), findsOneWidget);

    // Verify animated dots row is present
    expect(find.byType(Row), findsOneWidget);
  });
}
