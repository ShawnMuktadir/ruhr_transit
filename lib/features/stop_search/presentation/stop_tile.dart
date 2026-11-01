import 'package:flutter/material.dart';
import 'package:ruhr_transit/core/domain/transport_mode.dart';
import 'package:ruhr_transit/core/widgets/transport_mode_icon.dart';
import 'package:ruhr_transit/features/departures/presentation/departures_page.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';

/// A stop in a list (search results, favourites, nearby stops). Tapping it
/// opens its departure board, or calls [onSelected] if set.
class StopTile extends StatelessWidget {
  const StopTile(
    this.stop, {
    this.isFavourite = false,
    this.detail,
    this.onSelected,
    super.key,
  });

  final Stop stop;
  final bool isFavourite;

  /// Shown after the town, e.g. the distance of a nearby stop.
  final String? detail;

  /// Replaces opening the board, e.g. when picking a stop for a trip.
  final ValueChanged<Stop>? onSelected;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(isFavourite ? Icons.star : Icons.place_outlined),
      title: Text(stop.name),
      subtitle: switch ([?stop.locality, ?detail]) {
        [] => null,
        final parts => Text(parts.join(' · ')),
      },
      trailing: _ModeIcons(stop.modes),
      onTap: switch (onSelected) {
        final onSelected? => () => onSelected(stop),
        null => () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => DeparturesPage(stop: stop)),
        ),
      },
    );
  }
}

class _ModeIcons extends StatelessWidget {
  const _ModeIcons(this.modes);

  final Set<TransportMode> modes;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Enum order, so every row lists modes the same way.
        for (final mode in TransportMode.values)
          if (modes.contains(mode))
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: TransportModeIcon(mode, size: 20, color: color),
            ),
      ],
    );
  }
}
