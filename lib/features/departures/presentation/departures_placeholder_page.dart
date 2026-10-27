import 'package:flutter/material.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/core/widgets/data_attribution.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';

/// Temporary target after picking a stop. Replaced by the departure board
/// in Phase 2.
class DeparturesPlaceholderPage extends StatelessWidget {
  const DeparturesPlaceholderPage({required this.stop, super.key});

  final Stop stop;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(stop.fullName)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            AppLocalizations.of(context).departuresComingSoon,
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ),
      ),
      bottomNavigationBar: const DataAttribution(),
    );
  }
}
