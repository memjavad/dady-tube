import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dadytube/core/tactile_widgets.dart';

void main() {
  testWidgets('TactileButton renders with semantic label', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TactileButton(
            semanticLabel: 'Test Label',
            onTap: () {},
            child: const Icon(Icons.play_arrow),
          ),
        ),
      ),
    );

    final semantics = tester.semantics.find(find.byType(TactileButton));
    expect(semantics, isNotNull);
  });
}
