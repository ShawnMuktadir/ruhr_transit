import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:ruhr_transit/core/domain/geo_point.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/core/map/base_map.dart';
import 'package:ruhr_transit/features/departures/presentation/departures_page.dart';
import 'package:ruhr_transit/features/nearby_stops/domain/nearby_stop.dart';
import 'package:ruhr_transit/features/nearby_stops/domain/nearby_stops_repository.dart';

/// The stops around the user as pins, the user in the middle with the
/// search radius. Tapping a pin names the stop; tapping the name opens its
/// departures.
class NearbyMap extends StatefulWidget {
  const NearbyMap({
    required this.stops,
    required this.here,
    this.now = DateTime.now,
    super.key,
  });

  final List<NearbyStop> stops;
  final GeoPoint here;
  final DateTime Function() now;

  @override
  State<NearbyMap> createState() => _NearbyMapState();
}

class _NearbyMapState extends State<NearbyMap> {
  NearbyStop? _selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final here = toLatLng(widget.here);
    final selected = _selected;
    return Semantics(
      // The list is the accessible view of the same stops.
      label: l10n.mapNearbySummary(widget.stops.length),
      excludeSemantics: true,
      child: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCameraFit: CameraFit.coordinates(
                coordinates: [
                  here,
                  for (final nearby in widget.stops)
                    toLatLng(
                      GeoPoint(nearby.stop.latitude, nearby.stop.longitude),
                    ),
                ],
                padding: const EdgeInsets.all(48),
                maxZoom: 17,
              ),
              maxZoom: BaseMap.maxZoom,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onTap: (_, _) => setState(() => _selected = null),
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
                    Marker(
                      point: toLatLng(
                        GeoPoint(nearby.stop.latitude, nearby.stop.longitude),
                      ),
                      width: 44,
                      height: 44,
                      alignment: Alignment.topCenter,
                      child: GestureDetector(
                        onTap: () => setState(() => _selected = nearby),
                        child: Icon(
                          Icons.location_on,
                          size: 40,
                          color: identical(nearby, selected)
                              ? colors.tertiary
                              : colors.primary,
                          shadows: const [
                            Shadow(blurRadius: 3, color: Colors.black26),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              BaseMap.credit(context, widget.now()),
            ],
          ),
          if (selected != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 40,
              child: Card(
                child: ListTile(
                  leading: const Icon(Icons.departure_board),
                  title: Text(selected.stop.name),
                  subtitle: Text(
                    [
                      ?selected.stop.locality,
                      l10n.nearbyDistance(selected.distanceMeters),
                    ].join(' · '),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => DeparturesPage(stop: selected.stop),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
