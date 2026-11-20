import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/widgets/now_builder.dart';

void main() {
  testWidgets('builds again with the new time, so "in N min" counts down', (
    tester,
  ) async {
    var now = DateTime(2026, 11, 20, 8);
    final leaves = DateTime(2026, 11, 20, 8, 5);
    await tester.pumpWidget(
      MaterialApp(
        home: NowBuilder(
          now: () => now,
          builder: (context, now) =>
              Text('in ${leaves.difference(now).inMinutes} min'),
        ),
      ),
    );
    expect(find.text('in 5 min'), findsOneWidget);

    now = now.add(const Duration(minutes: 2));
    await tester.pump(const Duration(seconds: 15));

    expect(find.text('in 3 min'), findsOneWidget);
  });
}
