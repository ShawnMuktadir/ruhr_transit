import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/features/departures/presentation/departures_cubit.dart';
import 'package:ruhr_transit/features/departures/presentation/departures_page.dart';
import 'package:ruhr_transit/features/departures/presentation/show_cancelled_cubit.dart';
import 'package:ruhr_transit/features/favourites/presentation/favourites_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../../helpers/fake_departure_repository.dart';
import '../../../helpers/fake_favourites_repository.dart';
import '../../../helpers/fake_stop_repository.dart';

void main() {
  late ShowCancelledCubit showCancelled;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    showCancelled = ShowCancelledCubit(SharedPreferencesAsync());
  });
  tearDown(() => showCancelled.close());

  Future<void> pumpBoard(WidgetTester tester) async {
    final repository = FakeDepartureRepository()
      ..autoReply = Ok([delayedRe16, cancelledRe11, movedU35]);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: showCancelled),
          BlocProvider(
            create: (_) => FavouritesCubit(FakeFavouritesRepository()),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider(
            create: (_) =>
                DeparturesCubit(repository, bochumHbf.id, now: () => boardTime)
                  ..load(),
            child: const DeparturesView(stop: bochumHbf),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('cancelled departures show until switched off', (tester) async {
    await pumpBoard(tester);
    expect(find.text('Cancelled'), findsOneWidget);

    await tester.tap(find.byType(PopupMenuButton<void>));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CheckedPopupMenuItem<void>>(
            find.byType(CheckedPopupMenuItem<void>),
          )
          .checked,
      isTrue,
    );
    await tester.tap(find.text('Show cancelled departures'));
    await tester.pumpAndSettle();

    expect(showCancelled.state, isFalse);
    expect(find.text('Cancelled'), findsNothing);
    expect(find.text('1 cancelled departure hidden'), findsOneWidget);
    // The others stay.
    expect(find.textContaining('RE16', findRichText: true), findsOneWidget);
  });

  test('the choice is saved', () async {
    await showCancelled.set(false);
    final later = ShowCancelledCubit(SharedPreferencesAsync());
    addTearDown(later.close);
    await Future<void>.delayed(Duration.zero);
    expect(later.state, isFalse);
  });
}
