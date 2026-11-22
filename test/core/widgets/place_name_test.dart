import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/widgets/place_name.dart';

void main() {
  Future<(String, String)> nameAndArrow(
    WidgetTester tester,
    TextDirection direction,
  ) async {
    late (String, String) result;
    await tester.pumpWidget(
      Directionality(
        textDirection: direction,
        child: Builder(
          builder: (context) {
            result = (
              'Röhlinghauser Str.'.isolatedIn(context),
              routeArrow(context),
            );
            return const SizedBox();
          },
        ),
      ),
    );
    return result;
  }

  // Seen in Arabic: "Röhlinghauser Str." showed as ".Röhlinghauser Str".
  testWidgets('right to left, a name keeps its own direction', (tester) async {
    final (name, arrow) = await nameAndArrow(tester, TextDirection.rtl);
    expect(name, '\u2068Röhlinghauser Str.\u2069');
    expect(arrow, '←');
  });

  testWidgets('left to right, nothing changes', (tester) async {
    final (name, arrow) = await nameAndArrow(tester, TextDirection.ltr);
    expect(name, 'Röhlinghauser Str.');
    expect(arrow, '→');
  });
}
