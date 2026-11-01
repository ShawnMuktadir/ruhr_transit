import 'package:flutter/material.dart';
import 'package:ruhr_transit/core/domain/transport_mode.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/core/widgets/data_attribution.dart';
import 'package:ruhr_transit/core/widgets/line_badge.dart';
import 'package:ruhr_transit/core/widgets/platform_chip.dart';
import 'package:ruhr_transit/features/favourite_journeys/presentation/favourite_journey_button.dart';
import 'package:ruhr_transit/features/trip_planner/domain/journey.dart';
import 'package:ruhr_transit/features/trip_planner/domain/trip_query.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/trip_widgets.dart';

/// Less spare time than this after walking is flagged as a short
/// connection.
const shortConnection = Duration(minutes: 3);

/// Every leg of one journey, with the time to change between rides.
class JourneyDetailsPage extends StatelessWidget {
  const JourneyDetailsPage({required this.journey, this.query, super.key});

  final Journey journey;

  /// What was searched; its stops can be saved as a favourite journey.
  final TripQuery? query;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tripDetailsTitle),
        actions: [
          if (query case final query?)
            FavouriteJourneyButton(from: query.from, to: query.to),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          ListTile(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [JourneyDate(journey), JourneyTimes(journey)],
            ),
            subtitle: Text(
              [
                formatTripDuration(l10n, journey.duration),
                if (journey.transfers == 0)
                  l10n.tripDirect
                else
                  l10n.tripTransfers(journey.transfers),
              ].join(' · '),
            ),
          ),
          const Divider(),
          ..._legsWithChanges(journey.legs),
        ],
      ),
      bottomNavigationBar: const DataAttribution(),
    );
  }

  /// The legs, with a change row before every ride that follows another
  /// ride. Walks in between count towards the change time.
  static List<Widget> _legsWithChanges(List<Leg> legs) {
    final widgets = <Widget>[];
    TransitLeg? previousRide;
    var walking = Duration.zero;
    for (final leg in legs) {
      switch (leg) {
        case WalkLeg():
          walking += leg.duration;
          widgets.add(_WalkTile(leg));
        case TransitLeg():
          if (previousRide != null) {
            widgets.add(
              _ChangeTile(
                gap: leg.origin.time.difference(previousRide.destination.time),
                walking: walking,
              ),
            );
          }
          widgets.add(_RideTile(leg));
          previousRide = leg;
          walking = Duration.zero;
      }
    }
    return widgets;
  }
}

class _RideTile extends StatelessWidget {
  const _RideTile(this.leg);

  final TransitLeg leg;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              LineBadge(leg.line, mode: leg.mode),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.tripDirection(leg.direction),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _StopRow(leg.origin, mode: leg.mode),
          _StopRow(leg.destination, mode: leg.mode),
          for (final note in leg.notes)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                note,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// `17:14 +3   Bochum Hbf`, with a [Gleis 8] chip under the name.
class _StopRow extends StatelessWidget {
  const _StopRow(this.stop, {this.mode});

  final TripStop stop;

  /// Of the leg, so a bus stop gets "Steig" instead of "Gleis".
  final TransportMode? mode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A minimum, not a fixed width: "10:14 AM +12" must still fit.
          ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: 120,
              // Leaves the stop name room at large font sizes.
              maxWidth: MediaQuery.sizeOf(context).width * 0.4,
            ),
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TripTimeText(stop, style: theme.textTheme.bodyLarge),
            ),
          ),
          // The platform goes under the name, so a long name and platform
          // do not have to share one line at large font sizes.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stop.name, style: theme.textTheme.bodyLarge),
                if (stop.platform != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: PlatformChip(
                      platform: stop.platform,
                      plannedPlatform: stop.plannedPlatform,
                      mode: mode,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WalkTile extends StatelessWidget {
  const _WalkTile(this.leg);

  final WalkLeg leg;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final minutes = leg.duration.inMinutes;
    return ListTile(
      dense: true,
      leading: const Icon(Icons.directions_walk),
      title: Text(switch (leg.distanceMeters) {
        final meters? => l10n.tripWalkDistance(minutes, meters),
        null => l10n.tripWalk(minutes),
      }),
      subtitle: Text('${leg.origin.name} → ${leg.destination.name}'),
    );
  }
}

/// Time between arriving and the next ride, flagged when walking leaves
/// less than [shortConnection] to spare.
class _ChangeTile extends StatelessWidget {
  const _ChangeTile({required this.gap, required this.walking});

  final Duration gap;
  final Duration walking;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isShort = gap - walking < shortConnection;
    final color = isShort ? theme.colorScheme.error : null;
    return ListTile(
      dense: true,
      leading: Icon(
        isShort ? Icons.warning_amber : Icons.transfer_within_a_station,
        color: color,
      ),
      title: Text(
        [
          l10n.tripChange(gap.inMinutes),
          if (isShort) l10n.tripShortChange,
        ].join(' · '),
        style: TextStyle(color: color),
      ),
    );
  }
}
