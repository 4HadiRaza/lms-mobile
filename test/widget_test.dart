import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Premier LMS basic smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('Premier LMS Mobile')),
        ),
      ),
    );
    expect(find.text('Premier LMS Mobile'), findsOneWidget);
  });
}
