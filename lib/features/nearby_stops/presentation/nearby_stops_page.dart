import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ruhr_transit/core/connectivity/offline_banner.dart';
import 'package:ruhr_transit/core/di/injection.dart';
import 'package:ruhr_transit/core/domain/geo_point.dart';
import 'package:ruhr_transit/core/domain/transport_mode.dart';
import 'package:ruhr_transit/core/error/failure_message.dart';
import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/core/widgets/app_loader.dart';
import 'package:ruhr_transit/core/widgets/centered_message.dart';
import 'package:ruhr_transit/core/widgets/data_attribution.dart';
import 'package:ruhr_transit/core/widgets/transport_mode_icon.dart';
import 'package:ruhr_transit/features/departures/domain/departure_board.dart';
import 'package:ruhr_transit/features/departures/domain/departure_repository.dart';
import 'package:ruhr_transit/features/departures/presentation/departures_page.dart';
import 'package:ruhr_transit/features/favourites/presentation/favourite_stop_button.dart';
import 'package:ruhr_transit/features/nearby_stops/domain/location_source.dart';
import 'package:ruhr_transit/features/nearby_stops/domain/nearby_stop.dart';
import 'package:ruhr_transit/features/nearby_stops/domain/nearby_stops_repository.dart';
import 'package:ruhr_transit/features/nearby_stops/presentation/nearby_map.dart';
import 'package:ruhr_transit/features/nearby_stops/presentation/nearby_stops_cubit.dart';
import 'package:ruhr_transit/features/nearby_stops/presentation/nearby_stops_state.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';
import 'package:ruhr_transit/features/stop_search/presentation/stop_tile.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/stop_actions.dart';

/// Composition root of the nearby stops page: creates the cubit and starts
/// it (see [NearbyStopsCubit.start]), then hands over to [NearbyStopsView], which tests can pump with
/// their own cubit.
class NearbyStopsPage extends StatelessWidget {
  const NearbyStopsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => NearbyStopsCubit(
        getIt<LocationSource>(),
        getIt<NearbyStopsRepository>(),
      )..start(),
      child: NearbyStopsView(departures: getIt.call<DepartureRepository>),
    );
  }
}

class NearbyStopsView extends StatelessWidget {
  const NearbyStopsView({this.departures, super.key});

  /// Makes one repository per stop for its next departures; without it the
  /// rows show none.
  final DepartureRepository Function()? departures;

  /// Retries what failed when the phone is back online.
  @override
  Widget build(BuildContext context) => OnReconnect(
    onReconnect: () {
      final cubit = context.read<NearbyStopsCubit>();
      if (cubit.state is NearbyFailed) unawaited(cubit.load());
    },
    child: Builder(builder: _build),
  );

  Widget _build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<NearbyStopsCubit>();
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.nearbyTitle),
        actions: [
          BlocSelector<NearbyStopsCubit, NearbyStopsState, bool>(
            selector: (state) =>
                state is! NearbyLocating && state is! NearbyLoading,
            builder: (context, enabled) => IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: l10n.refresh,
              onPressed: enabled ? cubit.load : null,
            ),
          ),
        ],
      ),
      body: BlocBuilder<NearbyStopsCubit, NearbyStopsState>(
        builder: (context, state) => switch (state) {
          NearbyIntro() => CenteredMessage(
            l10n.nearbyIntro,
            icon: Icons.near_me_outlined,
            action: FilledButton.icon(
              icon: const Icon(Icons.my_location),
              label: Text(l10n.nearbyUseLocation),
              onPressed: cubit.load,
            ),
          ),
          NearbyLocating() => AppLoader(message: l10n.nearbyLocating),
          NearbyLoading() => const AppLoader(),
          NearbyLoaded(:final stops) when stops.isEmpty => CenteredMessage(
            l10n.nearbyEmpty,
          ),
          NearbyLoaded(:final stops, :final isApproximate, :final here) =>
            _NearbyResults(
              stops,
              isApproximate: isApproximate,
              here: here,
              departures: departures,
            ),
          NearbyLocationProblem(:final problem) => _LocationProblem(problem),
          NearbyFailed(:final failure) => CenteredMessage.retry(
            failureMessage(l10n, failure),
            onRetry: cubit.load,
          ),
        },
      ),
      bottomNavigationBar: const DataAttribution(),
    );
  }
}

class _StopList extends StatelessWidget {
  const _StopList(
    this.stops, {
    required this.isApproximate,
    required this.onChosen,
    this.departures,
  });

  /// One request per stop, so only for the closest few.
  static const stopsWithDepartures = 3;

  final DepartureRepository Function()? departures;

  final List<NearbyStop> stops;
  final bool isApproximate;
  final ValueChanged<NearbyStop> onChosen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ListView(
      children: [
        // Approximate location can be off by more than the search radius.
        if (isApproximate)
          ColoredBox(
            color: theme.colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.nearbyApproximate,
                    style: TextStyle(
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(
                      onPressed: context
                          .read<NearbyStopsCubit>()
                          .openAppSettings,
                      child: Text(l10n.nearbyAllowPrecise),
                    ),
                  ),
                ],
              ),
            ),
          ),
        for (final (index, nearby) in stops.indexed)
          // The card with these two is on the map, which TalkBack cannot
          // use to find a stop; it offers them on the row (actions menu).
          Semantics(
            container: true,
            customSemanticsActions: {
              if (TripActions.maybeOf(context) case final actions?)
                CustomSemanticsAction(label: l10n.stopPlanFromHere): () =>
                    actions.planFrom(nearby.stop),
              CustomSemanticsAction(label: l10n.stopDepartures): () =>
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => DeparturesPage(stop: nearby.stop),
                    ),
                  ),
            },
            child: StopTile(
              nearby.stop,
              detail: l10n.nearbyDistance(nearby.distanceMeters),
              action: FavouriteStopButton(nearby.stop),
              onSelected: (_) => onChosen(nearby),
              below: switch (departures) {
                final departures? when index < stopsWithDepartures =>
                  _NextDepartures(
                    nearby.stop,
                    // A new stop in this place loads its own.
                    key: ValueKey(nearby.stop.id),
                    departures: departures,
                  ),
                _ => null,
              },
            ),
          ),
      ],
    );
  }
}

/// What went wrong reading the location, with the button that can fix it.
class _LocationProblem extends StatelessWidget {
  const _LocationProblem(this.problem);

  final LocationResult problem;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<NearbyStopsCubit>();
    // Problems the app cannot solve itself come with a settings button.
    final (message, settings) = switch (problem) {
      LocationOff() => (
        l10n.nearbyLocationOff,
        (l10n.nearbyOpenLocationSettings, cubit.openLocationSettings),
      ),
      LocationPermissionDenied(permanently: true) => (
        l10n.nearbyPermissionDeniedForever,
        (l10n.nearbyOpenAppSettings, cubit.openAppSettings),
      ),
      LocationPermissionDenied() => (l10n.nearbyPermissionDenied, null),
      LocationTimeout() || Located() => (l10n.nearbyTimeout, null),
    };
    return CenteredMessage(
      message,
      action: switch (settings) {
        (final label, final open) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton.tonal(onPressed: open, child: Text(label)),
            // After changing the setting, the user comes back and retries.
            TextButton(onPressed: cubit.load, child: Text(l10n.retry)),
          ],
        ),
        null => RetryButton(cubit.load),
      },
    );
  }
}

/// The stops as a list or on a map; the list first, as it is what TalkBack
/// reads.
class _NearbyResults extends StatefulWidget {
  const _NearbyResults(
    this.stops, {
    required this.isApproximate,
    required this.here,
    this.departures,
  });

  final DepartureRepository Function()? departures;

  final List<NearbyStop> stops;
  final bool isApproximate;
  final GeoPoint? here;

  @override
  State<_NearbyResults> createState() => _NearbyResultsState();
}

class _NearbyResultsState extends State<_NearbyResults> {
  var _onMap = false;
  final _chosen = <_ModeFilter>{};
  NearbyStop? _selected;

  /// Without a position there is no map to show it on.
  void _openDepartures(NearbyStop nearby) => unawaited(
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DeparturesPage(stop: nearby.stop),
      ),
    ),
  );

  /// A tap in the list or on a pin: shows the stop on the map.
  void _select(NearbyStop? nearby) => setState(() {
    _selected = nearby;
    if (nearby != null) _onMap = true;
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final here = widget.here;
    final available = [
      for (final filter in _ModeFilter.values)
        if (widget.stops.any(filter.matches)) filter,
    ];
    // A refresh may have removed a mode: then it no longer filters.
    final active = _chosen.intersection(available.toSet());
    final stops = active.isEmpty
        ? widget.stops
        : [
            for (final stop in widget.stops)
              if (active.any((filter) => filter.matches(stop))) stop,
          ];
    // A filter or refresh may have hidden the chosen stop.
    final selected = stops.contains(_selected) ? _selected : null;
    final list = _StopList(
      stops,
      isApproximate: widget.isApproximate,
      onChosen: here == null ? _openDepartures : _select,
      departures: widget.departures,
    );
    return Column(
      children: [
        if (here != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                    value: false,
                    icon: const Icon(Icons.list),
                    label: Text(l10n.nearbyViewList),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: const Icon(Icons.map_outlined),
                    label: Text(l10n.nearbyViewMap),
                  ),
                ],
                selected: {_onMap},
                onSelectionChanged: (choice) =>
                    setState(() => _onMap = choice.single),
              ),
            ),
          ),
        // One mode alone has nothing to choose between.
        if (available.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: SizedBox(
              width: double.infinity,
              // Wraps at large text instead of overflowing.
              child: Wrap(
                spacing: 8,
                children: [
                  for (final filter in available)
                    FilterChip(
                      label: Text(transportModeLabel(l10n, filter.mode)),
                      selected: active.contains(filter),
                      onSelected: (selected) => setState(
                        () => selected
                            ? _chosen.add(filter)
                            : _chosen.remove(filter),
                      ),
                    ),
                ],
              ),
            ),
          ),
        Expanded(
          child: _onMap && here != null
              ? NearbyMap(
                  stops: stops,
                  here: here,
                  selected: selected,
                  onSelected: _select,
                )
              : list,
        ),
      ],
    );
  }
}

/// What the chips filter by. To passengers an S-Bahn is a train, so "Train"
/// covers both.
enum _ModeFilter {
  bus(TransportMode.bus, {TransportMode.bus}),
  tram(TransportMode.tram, {TransportMode.tram}),
  subway(TransportMode.subway, {TransportMode.subway}),
  train(TransportMode.train, {
    TransportMode.train,
    TransportMode.suburbanTrain,
  });

  const _ModeFilter(this.mode, this.modes);

  /// Names the chip.
  final TransportMode mode;
  final Set<TransportMode> modes;

  bool matches(NearbyStop nearby) => nearby.stop.modes.any(modes.contains);
}

/// The next two departures of a stop, e.g. "365 in 4 min · 355 in 14 min".
/// Nothing while loading or when it fails: the row is complete without.
class _NextDepartures extends StatefulWidget {
  const _NextDepartures(this.stop, {required this.departures, super.key});

  final Stop stop;
  final DepartureRepository Function() departures;

  @override
  State<_NextDepartures> createState() => _NextDeparturesState();
}

class _NextDeparturesState extends State<_NextDepartures> {
  /// When the list is rebuilt the answer stays; a reload makes a new row.
  late final Future<Result<DepartureBoard>> _board = widget
      .departures()
      .departuresAt(widget.stop.id);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return FutureBuilder(
      future: _board,
      builder: (context, snapshot) {
        if (snapshot.data case Ok(value: final board)) {
          final now = DateTime.now();
          final next = board.departures
              .where((d) => !d.isCancelled && !d.time.isBefore(now))
              .take(2);
          if (next.isNotEmpty) {
            return Text(
              [
                for (final departure in next)
                  switch (departure.time.difference(now).inMinutes) {
                    < 1 => l10n.nearbyNextNow(departure.line),
                    final minutes => l10n.nearbyNextIn(departure.line, minutes),
                  },
              ].join(' · '),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            );
          }
        }
        return const SizedBox.shrink();
      },
    );
  }
}
