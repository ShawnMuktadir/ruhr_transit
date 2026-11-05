import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:ruhr_transit/core/domain/geo_point.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/core/map/base_map.dart';
import 'package:ruhr_transit/features/departures/presentation/departures_page.dart';
import 'package:ruhr_transit/features/nearby_stops/domain/nearby_stop.dart';
import 'package:ruhr_transit/features/nearby_stops/domain/nearby_stops_repository.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/stop_actions.dart';

GeoPoint _pointOf(NearbyStop nearby) =>
    GeoPoint(nearby.stop.latitude, nearby.stop.longitude);

/// The stops around the user as pins, the user in the middle with the
/// search radius. The chosen stop has a large pin with a ring, the map
/// centres on it, and a card offers planning a trip from it.
class NearbyMap extends StatefulWidget {
  const NearbyMap({
    required this.stops,
    required this.here,
    required this.onSelected,
    this.selected,
    this.now = DateTime.now,
    super.key,
  });

  final List<NearbyStop> stops;
  final GeoPoint here;

  /// The chosen stop; kept by the page, as a tap in the list chooses too.
  final NearbyStop? selected;

  /// A pin was tapped, or null for the map around them.
  final ValueChanged<NearbyStop?> onSelected;
  final DateTime Function() now;

  @override
  State<NearbyMap> createState() => _NearbyMapState();
}

class _NearbyMapState extends State<NearbyMap> {
  /// Close enough to see the stop's streets.
  static const _chosenZoom = 16.0;

  final _controller = MapController();
  var _ready = false;

  @override
  void didUpdateWidget(NearbyMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selected = widget.selected;
    if (_ready && selected != null && selected != oldWidget.selected) {
      _controller.move(
        toLatLng(_pointOf(selected)),
        // Never further out than the user had zoomed in.
        max(_controller.camera.zoom, _chosenZoom),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final here = toLatLng(widget.here);
    final selected = widget.selected;
    return Stack(
      children: [
        // The map is for looking: TalkBack hears a summary, and the list
        // is the accessible view of the same stops. The card stays readable.
        Semantics(
          label: l10n.mapNearbySummary(widget.stops.length),
          excludeSemantics: true,
          child: FlutterMap(
            mapController: _controller,
            options: MapOptions(
              // Opened by choosing a stop: on that stop, else all of them.
              initialCenter: selected == null
                  ? here
                  : toLatLng(_pointOf(selected)),
              initialZoom: _chosenZoom,
              initialCameraFit: selected != null
                  ? null
                  : CameraFit.coordinates(
                      coordinates: [
                        here,
                        for (final nearby in widget.stops)
                          toLatLng(_pointOf(nearby)),
                      ],
                      padding: const EdgeInsets.all(48),
                      maxZoom: 17,
                    ),
              maxZoom: BaseMap.maxZoom,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onMapReady: () => _ready = true,
              onTap: (_, _) => widget.onSelected(null),
            ),
            children: [
              BaseMap.tiles(context),
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: here,
                    radius: NearbyStopsRepository.radiusMeters.toDouble(),
                    useRadiusInMeter: true,
                    color: colors.primary.withValues(alpha: 0.08),
                    borderColor: colors.primary.withValues(alpha: 0.5),
                    borderStrokeWidth: 1.5,
                  ),
                  // The ring around the chosen stop.
                  if (selected != null)
                    CircleMarker(
                      point: toLatLng(_pointOf(selected)),
                      radius: 22,
                      color: colors.tertiary.withValues(alpha: 0.25),
                      borderColor: colors.tertiary,
                      borderStrokeWidth: 3,
                    ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: here,
                    width: 22,
                    height: 22,
                    child: Tooltip(
                      message: l10n.mapYou,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [
                            BoxShadow(blurRadius: 4, color: Colors.black38),
                          ],
                        ),
                      ),
                    ),
                  ),
                  for (final nearby in widget.stops)
                    if (nearby != selected) _pin(nearby, colors, chosen: false),
                  // Last, so it lies above the others.
                  if (selected != null) _pin(selected, colors, chosen: true),
                ],
              ),
              BaseMap.credit(context, widget.now()),
            ],
          ),
        ),
        if (selected != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 28,
            child: _ChosenStopCard(selected),
          ),
      ],
    );
  }

  Marker _pin(NearbyStop nearby, ColorScheme colors, {required bool chosen}) {
    final size = chosen ? 60.0 : 44.0;
    return Marker(
      point: toLatLng(_pointOf(nearby)),
      width: size,
      height: size,
      // The pin's tip on the stop.
      alignment: Alignment.topCenter,
      child: GestureDetector(
        onTap: () => widget.onSelected(nearby),
        child: Icon(
          Icons.location_on,
          size: chosen ? 58 : 40,
          color: chosen ? colors.tertiary : colors.primary,
          shadows: const [Shadow(blurRadius: 3, color: Colors.black26)],
        ),
      ),
    );
  }
}

/// The chosen stop: planning a trip from it first, its departures second.
class _ChosenStopCard extends StatelessWidget {
  const _ChosenStopCard(this.nearby);

  final NearbyStop nearby;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final stop = nearby.stop;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(stop.name, style: theme.textTheme.titleMedium),
            Text(
              [
                ?stop.locality,
                l10n.nearbyDistance(nearby.distanceMeters),
              ].join(' · '),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            // Wraps at large text instead of overflowing.
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                PlanFromStopButton(stop),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => DeparturesPage(stop: stop),
                    ),
                  ),
                  child: Text(l10n.stopDepartures),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
