import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/widgets/cards.dart';

void main() {
  testWidgets('GroupCard starts a short text at the edge, not centred', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GroupCard(
            children: [
              Padding(padding: EdgeInsets.all(16), child: Text('Short')),
              ListTile(title: Text('A row')),
            ],
          ),
        ),
      ),
    );

    // Lined up with the row's title, as in the settings' accessibility card.
    expect(
      tester.getTopLeft(find.text('Short')).dx,
      tester.getTopLeft(find.text('A row')).dx,
    );
  });
}
