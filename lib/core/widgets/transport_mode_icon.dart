import 'package:flutter/material.dart';
import 'package:ruhr_transit/core/domain/transport_mode.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';

/// Icon for a [TransportMode], labelled for screen readers.
class TransportModeIcon extends StatelessWidget {
  const TransportModeIcon(this.mode, {this.size, this.color, super.key});

  final TransportMode mode;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Icon(
      switch (mode) {
        TransportMode.train => Icons.train,
        TransportMode.suburbanTrain => Icons.directions_railway,
        TransportMode.subway => Icons.subway,
        TransportMode.tram => Icons.tram,
        TransportMode.bus => Icons.directions_bus,
      },
      size: size,
      color: color,
      semanticLabel: switch (mode) {
        TransportMode.train => l10n.modeTrain,
        TransportMode.suburbanTrain => l10n.modeSuburbanTrain,
        TransportMode.subway => l10n.modeSubway,
        TransportMode.tram => l10n.modeTram,
        TransportMode.bus => l10n.modeBus,
      },
    );
  }
}
