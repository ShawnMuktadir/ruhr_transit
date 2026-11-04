import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ruhr_transit/core/connectivity/offline_banner.dart';
import 'package:ruhr_transit/core/di/injection.dart';
import 'package:ruhr_transit/core/domain/geo_point.dart';
import 'package:ruhr_transit/core/error/failure_message.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/core/widgets/centered_message.dart';
import 'package:ruhr_transit/core/widgets/data_attribution.dart';
import 'package:ruhr_transit/features/nearby_stops/domain/location_source.dart';
import 'package:ruhr_transit/features/nearby_stops/domain/nearby_stop.dart';
import 'package:ruhr_transit/features/nearby_stops/domain/nearby_stops_repository.dart';
import 'package:ruhr_transit/features/nearby_stops/presentation/nearby_map.dart';
import 'package:ruhr_transit/features/nearby_stops/presentation/nearby_stops_cubit.dart';
import 'package:ruhr_transit/features/nearby_stops/presentation/nearby_stops_state.dart';
import 'package:ruhr_transit/features/stop_search/presentation/stop_tile.dart';

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
      child: const NearbyStopsView(),
    );
  }
}

class NearbyStopsView extends StatelessWidget {
  const NearbyStopsView({super.key});

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
          NearbyLocating() => _Progress(l10n.nearbyLocating),
          NearbyLoading() => const _Progress(null),
          NearbyLoaded(:final stops) when stops.isEmpty => CenteredMessage(
            l10n.nearbyEmpty,
          ),
          NearbyLoaded(:final stops, :final isApproximate, :final here) =>
            _NearbyResults(stops, isApproximate: isApproximate, here: here),
          NearbyLocationProblem(:final problem) => _LocationProblem(problem),
          NearbyFailed(:final failure) => CenteredMessage(
            failureMessage(l10n, failure),
            action: FilledButton.tonal(
              onPressed: cubit.load,
              child: Text(l10n.retry),
            ),
          ),
        },
      ),
      bottomNavigationBar: const DataAttribution(),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress(this.text);

  final String? text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (text case final text?) ...[
            const SizedBox(height: 16),
            Text(text),
          ],
        ],
      ),
    );
  }
}

class _StopList extends StatelessWidget {
  const _StopList(this.stops, {required this.isApproximate});

  final List<NearbyStop> stops;
  final bool isApproximate;

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
        for (final nearby in stops)
          StopTile(
            nearby.stop,
            detail: l10n.nearbyDistance(nearby.distanceMeters),
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
        null => FilledButton.tonal(
          onPressed: cubit.load,
          child: Text(l10n.retry),
        ),
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
  });

  final List<NearbyStop> stops;
  final bool isApproximate;
  final GeoPoint? here;

  @override
  State<_NearbyResults> createState() => _NearbyResultsState();
}

class _NearbyResultsState extends State<_NearbyResults> {
  var _onMap = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final here = widget.here;
    final list = _StopList(widget.stops, isApproximate: widget.isApproximate);
    if (here == null) return list;
    return Column(
      children: [
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
        Expanded(
          child: _onMap ? NearbyMap(stops: widget.stops, here: here) : list,
        ),
      ],
    );
  }
}
