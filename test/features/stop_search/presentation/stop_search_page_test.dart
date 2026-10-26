import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/error/failure.dart';
import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/features/departures/presentation/departures_placeholder_page.dart';
import 'package:ruhr_transit/features/stop_search/presentation/stop_search_cubit.dart';
import 'package:ruhr_transit/features/stop_search/presentation/stop_search_page.dart';

import '../../../helpers/fake_stop_repository.dart';

void main() {
  late FakeStopRepository repository;

  setUp(() => repository = FakeStopRepository());

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider(
          create: (_) => StopSearchCubit(repository),
          child: const StopSearchView(),
        ),
      ),
    );
  }

  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(SearchBar), query);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
  }

  testWidgets('shows the hint before searching', (tester) async {
    await pumpPage(tester);

    expect(find.textContaining('at least two letters'), findsOneWidget);
    expect(find.byTooltip('Clear search'), findsNothing);
  });

  testWidgets('shows results and opens the placeholder on tap', (tester) async {
    // Needed to find the transport icons by their screen reader labels.
    // ListTile merges them into one label per row, e.g. "Hbf\nBochum\nTrain…".
    final semantics = tester.ensureSemantics();
    repository.autoReply = const Ok([bochumHbf, dortmundHbf]);
    await pumpPage(tester);

    await search(tester, 'Hbf');

    expect(find.text('Bochum'), findsOneWidget);
    expect(find.text('Dortmund'), findsOneWidget);
    // Only Bochum Hbf has train service in the fake data.
    expect(
      find.bySemanticsLabel(RegExp('Bochum.*Train', dotAll: true)),
      findsOneWidget,
    );
    // Must be disposed inside the test body; tear-downs run too late.
    semantics.dispose();

    await tester.tap(find.text('Bochum'));
    await tester.pumpAndSettle();

    expect(find.byType(DeparturesPlaceholderPage), findsOneWidget);
    expect(find.text('Bochum, Hbf'), findsOneWidget);
    expect(find.textContaining('All information without guarantee'), findsOne);
  });

  testWidgets('shows the empty state with the query', (tester) async {
    repository.autoReply = const Ok([]);
    await pumpPage(tester);

    await search(tester, 'xqzzqxv');

    expect(find.text('No stops found for “xqzzqxv”.'), findsOneWidget);
  });

  testWidgets('shows the error and retries', (tester) async {
    repository.autoReply = const Err(TimeoutFailure());
    await pumpPage(tester);

    await search(tester, 'Bochum');
    expect(find.textContaining('not responding'), findsOneWidget);

    repository.autoReply = const Ok([bochumHbf]);
    await tester.tap(find.text('Try again'));
    await tester.pump();

    expect(repository.queries, ['Bochum', 'Bochum']);
    expect(find.text('Bochum'), findsWidgets);
    expect(find.byType(ListTile), findsOneWidget);
  });

  testWidgets('clear button empties the field and returns to the hint', (
    tester,
  ) async {
    repository.autoReply = const Ok([bochumHbf]);
    await pumpPage(tester);
    await search(tester, 'Bochum');
    expect(find.byType(ListTile), findsOneWidget);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump();

    expect(find.byType(ListTile), findsNothing);
    expect(find.textContaining('at least two letters'), findsOneWidget);
  });
}
