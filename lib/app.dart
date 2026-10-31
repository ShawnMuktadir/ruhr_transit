import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ruhr_transit/core/di/injection.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/core/theme/app_theme.dart';
import 'package:ruhr_transit/features/favourites/domain/favourites_repository.dart';
import 'package:ruhr_transit/features/favourites/presentation/favourites_cubit.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';
import 'package:ruhr_transit/features/stop_search/presentation/stop_search_page.dart';

class RuhrTransitApp extends StatelessWidget {
  const RuhrTransitApp({this.initialFavourites = const [], super.key});

  /// What the favourites repository had stored when the app started.
  final List<Stop> initialFavourites;

  @override
  Widget build(BuildContext context) {
    // Above MaterialApp, so every route (search, departure boards) shares
    // the same favourites.
    return BlocProvider(
      create: (_) => FavouritesCubit(
        getIt<FavouritesRepository>(),
        initial: initialFavourites,
      ),
      child: MaterialApp(
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
