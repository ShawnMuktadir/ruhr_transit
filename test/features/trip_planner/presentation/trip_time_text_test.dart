import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/features/trip_planner/domain/journey.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/trip_widgets.dart';

void main() {
  Future<void> pumpTimes(WidgetTester tester, List<TripStop> stops) =>
      tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child!,
          ),
          home: Scaffold(
            body: Column(children: [for (final s in stops) TripTimeText(s)]),
          ),
        ),
      );

  String clock(DateTime utc) {
    final local = utc.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)}';
  }

  testWidgets('a late arrival shows when it arrives, not before departure', (
    tester,
  ) async {
    // Seen live: the trip leaves at 7:44, its RE2 was planned to arrive at
    // 7:37 and is 53 min late. It used to read "7:44 → 7:37 +53".
    final departs = TripStop(
      name: 'Gelsenkirchen, Buer Rathaus/Kunstmuseum',
      plannedTime: DateTime.utc(2026, 11, 20, 18, 44),
    );
    final arrives = TripStop(
      name: 'Mülheim Hbf',
      plannedTime: DateTime.utc(2026, 11, 20, 18, 37),
      estimatedTime: DateTime.utc(2026, 11, 20, 19, 30),
    );
    await pumpTimes(tester, [departs, arrives]);

    expect(find.text(clock(departs.plannedTime)), findsOneWidget);
    expect(find.text(clock(arrives.time)), findsOneWidget);
    final planned = tester.widget<Text>(find.text(clock(arrives.plannedTime)));
    expect(planned.style?.decoration, TextDecoration.lineThrough);
    expect(find.text('+53'), findsNothing);
    expect(
      find.bySemanticsLabel('${clock(arrives.time)}, 53 min late'),
      findsOneWidget,
    );
  });

  testWidgets('on time shows one time', (tester) async {
    final stop = TripStop(
      name: 'Bochum Hbf',
      plannedTime: DateTime.utc(2026, 11, 20, 18, 44),
      estimatedTime: DateTime.utc(2026, 11, 20, 18, 44),
    );
    await pumpTimes(tester, [stop]);

    expect(find.byType(Text), findsOneWidget);
  });
}
