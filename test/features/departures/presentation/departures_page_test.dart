import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/error/failure.dart';
import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/features/departures/presentation/departures_cubit.dart';
import 'package:ruhr_transit/features/departures/presentation/departures_page.dart';

import '../../../helpers/fake_departure_repository.dart';
import '../../../helpers/fake_stop_repository.dart';

void main() {
  late FakeDepartureRepository repository;

  setUp(() => repository = FakeDepartureRepository());

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // Times are shown in the device time zone, which differs between
        // machines; 24-hour format at least fixes the pattern.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        ),
        home: BlocProvider(
          create: (_) => DeparturesCubit(repository, bochumHbf.id)..load(),
          child: const DeparturesView(stop: bochumHbf),
        ),
      ),
    );
    await tester.pump();
  }

  String localTime(DateTime utc) {
    final local = utc.toLocal();
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }

  testWidgets('shows the stop name and the board with attribution', (
    tester,
  ) async {
    repository.autoReply = Ok([delayedRe16, cancelledRe11, movedU35]);
    await pumpPage(tester);

    expect(repository.stopIds, [bochumHbf.id]);
    expect(find.text('Bochum, Hbf'), findsOneWidget);
    expect(find.text('RE16'), findsOneWidget);
    expect(find.text('Essen Hauptbahnhof'), findsOneWidget);
    expect(find.text(localTime(delayedRe16.plannedTime)), findsOneWidget);
    expect(find.text('+12'), findsOneWidget);
    expect(find.text('Vorfahrt eines anderen Zuges'), findsOneWidget);
    expect(find.textContaining('All information without guarantee'), findsOne);
  });

  testWidgets('marks cancelled departures and platform changes', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    repository.autoReply = Ok([cancelledRe11, movedU35]);
    await pumpPage(tester);

    expect(find.text('Cancelled'), findsOneWidget);
    final cancelledTime = tester.widget<Text>(
      find.text(localTime(cancelledRe11.plannedTime)),
    );
    expect(cancelledTime.style?.decoration, TextDecoration.lineThrough);
    expect(
      find.bySemanticsLabel(RegExp('Platform changed to Gleis 3 \\(U\\)')),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('announces delays in words for screen readers', (tester) async {
    final semantics = tester.ensureSemantics();
    repository.autoReply = Ok([delayedRe16]);
    await pumpPage(tester);

    expect(find.bySemanticsLabel(RegExp('12 min late')), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('shows the empty board', (tester) async {
    repository.autoReply = const Ok([]);
    await pumpPage(tester);

    expect(find.text('No departures from this stop right now.'), findsOne);
  });

  testWidgets('shows the error and retries', (tester) async {
    repository.autoReply = const Err(NetworkFailure());
    await pumpPage(tester);
    expect(find.textContaining('No internet connection'), findsOneWidget);

    repository.autoReply = Ok([delayedRe16]);
    await tester.tap(find.text('Try again'));
    await tester.pump();

    expect(repository.stopIds, hasLength(2));
    expect(find.text('RE16'), findsOneWidget);
  });

  testWidgets('pull to refresh updates the board', (tester) async {
    repository.autoReply = Ok([delayedRe16]);
    await pumpPage(tester);

    repository.autoReply = Ok([delayedRe16, movedU35]);
    await tester.fling(find.text('RE16'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(repository.stopIds, hasLength(2));
    expect(find.text('U35'), findsOneWidget);
  });

  testWidgets('a failed refresh keeps the board and shows a snack bar', (
    tester,
  ) async {
    repository.autoReply = Ok([delayedRe16]);
    await pumpPage(tester);

    repository.autoReply = const Err(TimeoutFailure());
    await tester.tap(find.byTooltip('Refresh'));
    await tester.pump();

    expect(find.text('RE16'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.textContaining('not responding'),
      ),
      findsOneWidget,
    );
  });
}
