import 'package:flutter/material.dart';
import 'package:ruhr_transit/core/domain/transport_mode.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/core/widgets/cards.dart';
import 'package:ruhr_transit/core/widgets/place_name.dart';
import 'package:ruhr_transit/core/widgets/transport_mode_icon.dart';
import 'package:ruhr_transit/features/departures/presentation/departures_page.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';

/// A stop in a list (search results, favourites, nearby stops). Tapping it
/// opens its departure board, or calls [onSelected] if set.
class StopTile extends StatelessWidget {
  const StopTile(
    this.stop, {
    this.isFavourite = false,
    this.icon,
    this.detail,
    this.onSelected,
    this.action,
    this.below,
    super.key,
  });

  /// Under the town, e.g. a nearby stop's next departures.
  final Widget? below;

  /// After the mode icons, e.g. the star on a nearby stop.
  final Widget? action;

  final Stop stop;
  final bool isFavourite;

  /// Replaces the star or place icon, e.g. a clock for a recent stop.
  final IconData? icon;

  /// Shown after the town, e.g. the distance of a nearby stop.
  final String? detail;

  /// Replaces opening the board, e.g. when picking a stop for a trip.
  final ValueChanged<Stop>? onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kind = switch (stop.kind) {
      LocationKind.stop => null,
      LocationKind.address => l10n.locationAddress,
      LocationKind.place => l10n.locationPlace,
    };
    return ListCard(
      child: ListTile(
        leading: Icon(
          icon ??
              switch (stop.kind) {
                LocationKind.address => Icons.home_outlined,
                LocationKind.place => Icons.account_balance_outlined,
                LocationKind.stop =>
                  isFavourite ? Icons.star : Icons.place_outlined,
              },
        ),
        title: Text(stop.name.isolatedIn(context)),
        // "Adresse · Bochum": the kind first, so a street is not taken for a
        // stop of the same name. The modes follow the text, not the row's
        // end, so a big station's five icons leave the text its width; they
        // move to their own line when they do not fit.
        subtitle: switch ([
          if ([
                if ([?kind, ?stop.locality?.isolatedIn(context), ?detail]
                    case final parts when parts.isNotEmpty)
                  Text(parts.join(' · ')),
                if (stop.modes.isNotEmpty) _ModeIcons(stop.modes),
              ]
              case final line when line.isNotEmpty)
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: line,
            ),
          ?below,
        ]) {
          [] => null,
          [final only] => only,
          final lines => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: lines,
          ),
        },
        trailing: action,
        onTap: switch (onSelected) {
          final onSelected? => () => onSelected(stop),
          null => () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => DeparturesPage(stop: stop)),
          ),
        },
      ),
    );
  }
}

class _ModeIcons extends StatelessWidget {
  const _ModeIcons(this.modes);

  final Set<TransportMode> modes;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Wrap(
      spacing: 4,
      children: [
        // Enum order, so every row lists modes the same way.
        for (final mode in TransportMode.values)
          if (modes.contains(mode))
            TransportModeIcon(mode, size: 18, color: color),
      ],
    );
  }
}
