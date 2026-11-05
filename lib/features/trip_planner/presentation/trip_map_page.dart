import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:ruhr_transit/core/domain/geo_point.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/core/map/base_map.dart';
import 'package:ruhr_transit/core/widgets/cards.dart';
import 'package:ruhr_transit/core/widgets/transport_mode_icon.dart';
import 'package:ruhr_transit/features/trip_planner/domain/journey.dart';
import 'package:ruhr_transit/features/trip_planner/domain/vehicle_run_repository.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/vehicle_run_cubit.dart';

/// The points a leg is drawn with: its path, or failing that a straight
/// line between its stops.
List<GeoPoint> legLine(Leg leg) => leg.path.length >= 2
    ? leg.path
    : [?leg.origin.position, ?leg.destination.position];

/// Whether [journey] has anything to draw.
bool hasMap(Journey journey) =>
    journey.legs.any((leg) => legLine(leg).length >= 2);

/// The trip on a map: rides in their mode's colour, walks dotted, markers
/// at the start, the changes and the destination, and the vehicles where
/// their runs are known.
class TripMapPage extends StatelessWidget {
  const TripMapPage({
    required this.journey,
    this.runs,
    this.now = DateTime.now,
    super.key,
  });

  final Journey journey;

  /// One repository per ride for its vehicle; null shows no vehicles.
  final VehicleRunRepository Function()? runs;
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final legs = journey.legs;
    final rides = legs.whereType<TransitLeg>().toList();
    final points = [for (final leg in legs) ...legLine(leg)];

    final lines = [
      for (final leg in legs)
        if (legLine(leg) case final line when line.length >= 2)
          switch (leg) {
            TransitLeg(:final mode) => Polyline(
              points: [for (final p in line) toLatLng(p)],
              strokeWidth: 5,
              color: switch (mode) {
                final mode? => modeAccent(mode, brightness),
                null => theme.colorScheme.outline,
              },
              borderStrokeWidth: 1.5,
              borderColor: theme.colorScheme.surface,
            ),
            WalkLeg() => Polyline(
              points: [for (final p in line) toLatLng(p)],
              strokeWidth: 4,
              color: theme.colorScheme.onSurfaceVariant,
              pattern: const StrokePattern.dotted(),
            ),
          },
    ];

    // Start, every change between two rides, destination.
    final stops = <(GeoPoint, IconData, String)>[
      if (legs.first.origin.position case final p?)
        (p, Icons.trip_origin, l10n.mapStart),
      for (final ride in rides.skip(1))
        if (ride.origin.position case final p?)
          (p, Icons.transfer_within_a_station, l10n.mapChange),
      if (legs.last.destination.position case final p?)
        (p, Icons.place, l10n.mapDestination),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.mapTitle)),
      body: Semantics(
        // The map is for looking; the details list is the accessible view.
        label: l10n.mapTripSummary(
          legs.first.origin.name,
          legs.last.destination.name,
          rides.length,
        ),
        excludeSemantics: true,
        child: FlutterMap(
          options: MapOptions(
            initialCameraFit: CameraFit.coordinates(
              coordinates: [for (final p in points) toLatLng(p)],
              padding: const EdgeInsets.all(48),
              maxZoom: 17,
            ),
            maxZoom: BaseMap.maxZoom,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            BaseMap.tiles(context),
            PolylineLayer(polylines: lines),
            MarkerLayer(
              markers: [
                for (final (point, icon, label) in stops)
                  Marker(
                    point: toLatLng(point),
                    width: 36,
                    height: 36,
                    child: _StopMarker(icon: icon, label: label),
                  ),
              ],
            ),
            if (runs case final runs?)
              for (final ride in rides)
                if (ride.runKey case final key?)
                  BlocProvider(
                    create: (_) =>
                        VehicleRunCubit(runs(), key, now: now)..start(),
                    child: _VehicleMarker(ride, now: now),
                  ),
            BaseMap.credit(context, now()),
          ],
        ),
      ),
    );
  }
}

class _StopMarker extends StatelessWidget {
  const _StopMarker({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: colors.primary, width: 2),
          boxShadow: const [BoxShadow(blurRadius: 3, color: Colors.black26)],
        ),
        child: Icon(icon, size: 20, color: colors.primary),
      ),
    );
  }
}

/// The ride's vehicle, estimated between two stops from the run's times;
/// moves with the run's refresh. Nothing before its start or after its end.
class _VehicleMarker extends StatefulWidget {
  const _VehicleMarker(this.ride, {required this.now});

  final TransitLeg ride;
  final DateTime Function() now;

  @override
  State<_VehicleMarker> createState() => _VehicleMarkerState();
}

class _VehicleMarkerState extends State<_VehicleMarker> {
  /// Between the run's 30-second refreshes the dot still moves on.
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 5), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = context.watch<VehicleRunCubit>().state;
    final point = switch (state) {
      // Paused without a connection, like in the trip details.
      VehicleRunLoaded(:final run, isPaused: true, :final now) => run.pointAt(
        now,
      ),
      VehicleRunLoaded(:final run) => run.pointAt(widget.now()),
      _ => null,
    };
    if (point == null) return const SizedBox.shrink();
    final mode = widget.ride.mode;
    final color = switch (mode) {
      final mode? => modeAccent(mode, theme.brightness),
      null => theme.colorScheme.outline,
    };
    return MarkerLayer(
      markers: [
        Marker(
          point: toLatLng(point),
          width: 34,
          height: 34,
          child: Tooltip(
            message: l10n.mapVehicle(widget.ride.line),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [
                  BoxShadow(blurRadius: 4, color: Colors.black38),
                ],
              ),
              child: switch (mode) {
                final mode? => TransportModeIcon(
                  mode,
                  size: 18,
                  color: Colors.white,
                ),
                null => const SizedBox.shrink(),
              },
            ),
          ),
        ),
      ],
    );
  }
}
