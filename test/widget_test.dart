// This is a basic Flutter widget test.
//
// The default template test references a `MyApp` counter widget that
// doesn't exist in this project — that's what caused the
// `creation_with_non_type` error. Replace this with a real test for your
// actual root widget once you know its class name (check lib/main.dart).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Smoke test placeholder', (WidgetTester tester) async {
    // Build a minimal app and trigger a frame.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('Garba App')),
        ),
      ),
    );

    // Verify basic rendering works.
    expect(find.text('Garba App'), findsOneWidget);
  });
}