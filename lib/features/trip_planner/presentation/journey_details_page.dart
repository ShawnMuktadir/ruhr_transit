import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ruhr_transit/core/di/injection.dart';
import 'package:ruhr_transit/core/error/failure_message.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/core/widgets/app_loader.dart';
import 'package:ruhr_transit/core/widgets/cards.dart';
import 'package:ruhr_transit/core/widgets/data_attribution.dart';
import 'package:ruhr_transit/core/widgets/line_badge.dart';
import 'package:ruhr_transit/core/widgets/show_message.dart';
import 'package:ruhr_transit/features/favourite_journeys/presentation/favourite_journey_button.dart';
import 'package:ruhr_transit/features/reminders/presentation/reminder_tile.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';
import 'package:ruhr_transit/features/trip_planner/domain/journey.dart';
import 'package:ruhr_transit/features/trip_planner/domain/trip_query.dart';
import 'package:ruhr_transit/features/trip_planner/domain/vehicle_run_repository.dart';
import 'package:ruhr_transit/features/trip_planner/domain/walk_to_stop.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/ride_stops.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/route_title.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/stop_actions.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/trip_map_page.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/trip_notices.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/trip_widgets.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/walk_directions.dart';

/// Less spare time than this after walking is flagged as a short
/// connection.
const shortConnection = Duration(minutes: 3);

/// Every leg of one journey, with the time to change between rides.
class JourneyDetailsPage extends StatefulWidget {
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
  State<JourneyDetailsPage> createState() => _JourneyDetailsPageState();
}

class _JourneyDetailsPageState extends State<JourneyDetailsPage> {
  /// The trip with the walk to its first ride, once the user asked for it.
  Journey? _withWalk;
  WalkLeg? _walk;
  var _finding = false;

  /// Only on the user's tap: it sends the location to VRR, and may ask for
  /// the permission.
  Future<void> _findWay(TripActions actions, Stop stop) async {
    final walk = actions.walkToStop();
    setState(() => _finding = true);
    final result = await walk.find(stop);
    if (!mounted) return;
    setState(() => _finding = false);

    final l10n = AppLocalizations.of(context);
    void say(String message) =>
        ScaffoldMessenger.of(context).showMessage(message);
    switch (result) {
      case WalkFound(:final journey):
        final route = journey.legs.whereType<WalkLeg>().firstOrNull;
        if (route == null) {
          say(l10n.stopWalkNotFound);
          return;
        }
        final withWalk = withWalkToFirstRide(widget.journey, route);
        setState(() {
          _withWalk = withWalk;
          _walk = withWalk.legs.first as WalkLeg;
        });
      case WalkNoLocation(:final problem):
        showHereProblem(context, problem, walk.finder);
      case WalkNotFound():
        say(l10n.stopWalkNotFound);
      case WalkFailed(:final failure):
        say(failureMessage(l10n, failure));
    }
  }

  /// The row offering the way to the first stop: only for a trip that
  /// starts with a ride, in the app (not in a test of the page alone).
  Widget? _wayToFirstStop(BuildContext context) {
    final actions = TripActions.maybeOf(context);
    final first = widget.journey.legs.first;
    if (actions == null || first is! TransitLeg || _withWalk != null) {
      return null;
    }
    final stop = boardingStopOf(first);
    if (stop == null) return null;
    final l10n = AppLocalizations.of(context);
    return ListCard(
      child: ListTile(
        leading: const Icon(Icons.directions_walk),
        title: Text(l10n.tripWayToStop(first.origin.name)),
        subtitle: Text(l10n.tripWayFromHere),
        trailing: _finding
            ? const AppLoader.small()
            : const Icon(Icons.chevron_right),
        onTap: _finding ? null : () => unawaited(_findWay(actions, stop)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final journey = _withWalk ?? widget.journey;
    final query = widget.query;
    final runs = widget.runs;
    final now = widget.now;
    final wayToFirstStop = _wayToFirstStop(context);
    final l10n = AppLocalizations.of(context);
    final notices = journey.notices;
    return Scaffold(
      appBar: RouteTitle.appBar(
        context,
        from: query?.from.fullName ?? journey.legs.first.origin.name,
        to: query?.to.fullName ?? journey.legs.last.destination.name,
        actions: [
          if (hasMap(journey))
            IconButton(
              icon: const Icon(Icons.map_outlined),
              tooltip: l10n.mapShowTrip,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      TripMapPage(journey: journey, runs: runs, now: now),
                ),
              ),
            ),
          if (query case final query?)
            FavouriteJourneyButton(from: query.from, to: query.to),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          ListCard(
            child: ListTile(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [JourneyDate(journey), JourneyTimes(journey)],
              ),
              subtitle: Text(
                [
                  formatTripDuration(l10n, journey.duration),
                  if (journey.legs.every((leg) => leg is WalkLeg))
                    l10n.tripWalkOnly
                  else if (journey.transfers == 0)
                    l10n.tripDirect
                  else
                    l10n.tripTransfers(journey.transfers),
                  if (journey.isTimetableOnly) l10n.tripTimetableOnlyDetail,
                ].join(' · '),
              ),
            ),
          ),
          ReminderTile(journey, query: query),
          if (notices.isNotEmpty) ListCard(child: TripNoticesSection(notices)),
          const SizedBox(height: 4),
          ?wayToFirstStop,
          ..._legsWithChanges(journey.legs, runs, now, opened: _walk),
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
    DateTime Function() now, {
    WalkLeg? opened,
  }) {
    final widgets = <Widget>[];
    TransitLeg? previousRide;
    var walking = Duration.zero;
    for (final leg in legs) {
      switch (leg) {
        case WalkLeg():
          walking += leg.duration;
          widgets.add(
            ListCard(
              child: _WalkTile(
                leg,
                // The whole journey, or the way the user just asked for.
                showDirections: legs.length == 1 || identical(leg, opened),
              ),
            ),
          );
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
          widgets.add(
            AccentCard(
              // Keeps its run and open rows when the walk appears above it.
              key: ObjectKey(leg),
              mode: leg.mode,
              child: _RideTile(leg, runs: runs, now: now),
            ),
          );
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
          // Side by side when they fit, else the direction goes below: at
          // large text on a narrow phone the badge alone can fill the row.
          Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              LineBadge(leg.line, mode: leg.mode),
              Text(
                l10n.tripDirection(leg.direction),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
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
  const _WalkTile(this.leg, {this.showDirections = false});

  final WalkLeg leg;

  /// The whole journey is this walk, so its directions are open.
  final bool showDirections;

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
          child: WalkDirections(
            steps: leg.steps,
            paths: leg.stationPaths,
            initiallyExpanded: showDirections,
          ),
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
