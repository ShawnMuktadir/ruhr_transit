import 'package:flutter/material.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';

/// VRR source credit. The API usage agreement requires it wherever VRR data
/// is shown, so every data screen uses this as its `bottomNavigationBar`.
class DataAttribution extends StatelessWidget {
  const DataAttribution({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          AppLocalizations.of(context).dataAttribution,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
