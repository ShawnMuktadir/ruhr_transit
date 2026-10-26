import 'package:flutter/material.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/core/theme/app_theme.dart';
import 'package:ruhr_transit/features/stop_search/presentation/stop_search_page.dart';

class RuhrTransitApp extends StatelessWidget {
  const RuhrTransitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      // German is listed first, so it is the fallback for any device locale
      // we don't support. English devices get English.
      supportedLocales: AppLocalizations.supportedLocales,
      debugShowCheckedModeBanner: false,
      home: const StopSearchPage(),
    );
  }
}
