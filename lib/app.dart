import 'package:flutter/material.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/core/theme/app_theme.dart';

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
      home: const _HomePlaceholder(),
    );
  }
}

/// Temporary start screen. Replaced by stop search in Phase 1.
class _HomePlaceholder extends StatelessWidget {
  const _HomePlaceholder();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.homePlaceholder,
            style: textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            l10n.dataAttribution,
            style: textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
