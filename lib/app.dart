import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ruhr_transit/core/di/injection.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/core/theme/app_theme.dart';
import 'package:ruhr_transit/features/departures/presentation/departures_page.dart';
import 'package:ruhr_transit/features/favourites/domain/favourites_repository.dart';
import 'package:ruhr_transit/features/favourites/presentation/favourites_cubit.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';
import 'package:ruhr_transit/features/stop_search/presentation/stop_search_page.dart';
import 'package:ruhr_transit/features/widget_sync/domain/widget_sync.dart';

class RuhrTransitApp extends StatefulWidget {
  const RuhrTransitApp({
    this.initialFavourites = const [],
    this.launchedStop,
    super.key,
  });

  /// What the favourites repository had stored when the app started.
  final List<Stop> initialFavourites;

  /// The stop whose home-screen widget started the app. Its board opens on
  /// top of the search screen, so Back leads to the search.
  final Stop? launchedStop;

  @override
  State<RuhrTransitApp> createState() => _RuhrTransitAppState();
}

class _RuhrTransitAppState extends State<RuhrTransitApp> {
  /// Opens boards from widget taps, which come from outside the widget tree.
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final StreamSubscription<Stop> _widgetTaps;

  @override
  void initState() {
    super.initState();
    _widgetTaps = getIt<WidgetSync>().openedStops.listen(_openBoard);
    if (widget.launchedStop case final stop?) {
      // The navigator exists only after the first frame.
      WidgetsBinding.instance.addPostFrameCallback((_) => _openBoard(stop));
    }
  }

  @override
  void dispose() {
    unawaited(_widgetTaps.cancel());
    super.dispose();
  }

  /// Shows [stop]'s board directly above the search, so repeated widget
  /// taps do not stack boards and Back always leads to the search.
  void _openBoard(Stop stop) {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    navigator.popUntil((route) => route.isFirst);
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => DeparturesPage(stop: stop)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Above MaterialApp, so every route (search, departure boards) shares
    // the same favourites.
    return BlocProvider(
      create: (_) => FavouritesCubit(
        getIt<FavouritesRepository>(),
        initial: widget.initialFavourites,
      ),
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        // German is listed first, so it is the fallback for any device locale
        // we don't support. English devices get English.
        supportedLocales: AppLocalizations.supportedLocales,
        debugShowCheckedModeBanner: false,
        home: const StopSearchPage(),
      ),
    );
  }
}
