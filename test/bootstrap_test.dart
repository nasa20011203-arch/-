import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Flutter engine can mount and render a widget', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Text('오프라인 캘린더')));
    expect(find.text('오프라인 캘린더'), findsOneWidget);
  });
}
