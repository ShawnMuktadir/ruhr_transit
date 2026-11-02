import 'package:flutter/material.dart';
import 'package:ruhr_transit/core/di/injection.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/core/widgets/data_attribution.dart';
import 'package:ruhr_transit/core/widgets/line_badge.dart';
import 'package:ruhr_transit/features/favourite_journeys/presentation/favourite_journey_button.dart';
import 'package:ruhr_transit/features/trip_planner/domain/journey.dart';
import 'package:ruhr_transit/features/trip_planner/domain/trip_query.dart';
import 'package:ruhr_transit/features/trip_planner/domain/vehicle_run_repository.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/ride_stops.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/trip_notices.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/trip_widgets.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/walk_directions.dart';

/// Less spare time than this after walking is flagged as a short
/// connection.
const shortConnection = Duration(minutes: 3);

/// Every leg of one journey, with the time to change between rides.
class JourneyDetailsPage extends StatelessWidget {
  const JourneyDetailsPage({
    required this.journey,
    this.query,
    this.runs = _runRepository,
    this.now = DateTime.now,
    super.key,
  });

  final Journey journey;

  /// What was searched; its stops can be saved as a favourite journey.
  final TripQuery? query;

  /// Makes one repository per ride for its vehicle's whole run (one each,
  /// so their refreshes do not cancel each other); tests pass a fake, null
  /// shows the rides without their runs.
  final VehicleRunRepository Function()? runs;

  /// The clock the vehicles' positions are calculated for.
  final DateTime Function() now;

  static VehicleRunRepository _runRepository() => getIt<VehicleRunRepository>();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final notices = journey.notices;
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
                if (journey.isTimetableOnly) l10n.tripTimetableOnlyDetail,
              ].join(' · '),
            ),
          ),
          if (notices.isNotEmpty) TripNoticesSection(notices),
          const Divider(),
          ..._legsWithChanges(journey.legs, runs, now),
        ],
      ),
      bottomNavigationBar: const DataAttribution(),
    );
  }

  /// The legs, with a change row before every ride that follows another
  /// ride. Walks in between count towards the change time.
  static List<Widget> _legsWithChanges(
    List<Leg> legs,
    VehicleRunRepository Function()? runs,
    DateTime Function() now,
  ) {
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
                // A change inside a station: its way is on the ride before.
                steps: previousRide.transferSteps,
                paths: previousRide.transferPaths,
              ),
            );
          }
          widgets.add(_RideTile(leg, runs: runs, now: now));
          previousRide = leg;
          walking = Duration.zero;
      }
    }
    return widgets;
  }
}

class _RideTile extends StatelessWidget {
  const _RideTile(this.leg, {required this.now, this.runs});

  final TransitLeg leg;
  final VehicleRunRepository Function()? runs;
  final DateTime Function() now;

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
          RideStops(leg, runs: runs, now: now),
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

class _WalkTile extends StatelessWidget {
  const _WalkTile(this.leg);

  final WalkLeg leg;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final minutes = leg.duration.inMinutes;
    final tile = ListTile(
      dense: true,
      leading: const Icon(Icons.directions_walk),
      title: Text(switch (leg.distanceMeters) {
        final meters? => l10n.tripWalkDistance(minutes, meters),
        null => l10n.tripWalk(minutes),
      }),
      subtitle: Text('${leg.origin.name} → ${leg.destination.name}'),
    );
    if (leg.steps.isEmpty) return tile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        tile,
        Padding(
          padding: const EdgeInsets.fromLTRB(56, 0, 16, 4),
          child: WalkDirections(steps: leg.steps, paths: leg.stationPaths),
        ),
      ],
    );
  }
}

/// Time between arriving and the next ride, flagged when walking leaves
/// less than [shortConnection] to spare.
class _ChangeTile extends StatelessWidget {
  const _ChangeTile({
    required this.gap,
    required this.walking,
    this.steps = const [],
    this.paths = const [],
  });

  final Duration gap;
  final Duration walking;
  final List<WalkStep> steps;
  final List<StationPath> paths;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isShort = gap - walking < shortConnection;
    final color = isShort ? theme.colorScheme.error : null;
    final tile = ListTile(
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
    if (steps.isEmpty) return tile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        tile,
        Padding(
          padding: const EdgeInsets.fromLTRB(56, 0, 16, 4),
          child: WalkDirections(steps: steps, paths: paths),
        ),
      ],
    );
  }
}
