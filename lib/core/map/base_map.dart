import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:ruhr_transit/core/domain/geo_point.dart';

/// basemap.de, the official map of Germany by the federal mapping agency
/// (BKG). Free of charge under CC BY 4.0, no access restrictions, no key
/// (WMTS capabilities, checked 2026-11-03). Covers Germany only, like the
/// app; web Mercator zoom 0–19.
abstract final class BaseMap {
  static const _tiles =
      'https://sgx.geodatenzentrum.de/wmts_basemapde/tile/1.0.0/'
      'de_basemapde_web_raster_{style}/default/GLOBAL_WEBMERCATOR/'
      '{z}/{y}/{x}.png';

  static const maxZoom = 19.0;

  /// The credit the licence asks for: "© GeoBasis-DE / BKG (year of the
  /// last data retrieval) CC BY 4.0". Tiles are fetched live, so the
  /// current year.
  static String attribution(DateTime now) =>
      '© GeoBasis-DE / BKG ${now.year} CC BY 4.0';

  /// The colour map, or in dark mode the grey one inverted: basemap.de
  /// has no dark style, and a bright map in a dark app glares.
  static Widget tiles(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return TileLayer(
      urlTemplate: _tiles,
      additionalOptions: {'style': dark ? 'grau' : 'farbe'},
      userAgentPackageName: 'de.muktadir.ruhrtransit',
      maxNativeZoom: maxZoom.toInt(),
      tileBuilder: dark ? darkModeTileBuilder : null,
    );
  }

  /// The licence credit in the map's corner. The widget puts the "©" in
  /// front itself.
  static Widget credit(BuildContext context, DateTime now) {
    final colors = Theme.of(context).colorScheme;
    return SimpleAttributionWidget(
      source: Text(
        attribution(now).replaceFirst('© ', ''),
        style: TextStyle(color: colors.onSurface),
      ),
      // Readable on the light and the dark map alike.
      backgroundColor: colors.surface.withValues(alpha: 0.85),
    );
  }
}

LatLng toLatLng(GeoPoint point) => LatLng(point.latitude, point.longitude);
