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

  /// The most map images kept on disk, so maps open faster and BKG gets
  /// fewer requests. flutter_map's default of 1 GB is far too much here.
  static const maxCacheBytes = 100 * 1000 * 1000;

  /// Makes the provider of the map images; tests replace it, as the disk
  /// cache needs a plugin that does not run there.
  @visibleForTesting
  static TileProvider Function() tileProvider = _cachedTiles;

  static TileProvider _cachedTiles() => NetworkTileProvider(
    cachingProvider: BuiltInMapCachingProvider.getOrCreateInstance(
      maxCacheSize: maxCacheBytes,
    ),
  );

  /// The colour map, or in dark mode the grey one inverted: basemap.de
  /// has no dark style, and a bright map in a dark app glares.
  static Widget tiles(BuildContext context) => const _Tiles();

  /// The licence credit in the map's corner. Not flutter_map's attribution
  /// widget: that one cannot wrap, so narrow screens and large text cut off
  /// the credit the licence asks for.
  static Widget credit(BuildContext context, DateTime now) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Align(
      alignment: Alignment.bottomRight,
      child: ColoredBox(
        // Readable on the light and the dark map alike.
        color: colors.surface.withValues(alpha: 0.85),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Text(
            attribution(now),
            style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurface),
          ),
        ),
      ),
    );
  }
}

/// Holds one provider per map: a new one on every build would reload the
/// images.
class _Tiles extends StatefulWidget {
  const _Tiles();

  @override
  State<_Tiles> createState() => _TilesState();
}

class _TilesState extends State<_Tiles> {
  late final _provider = BaseMap.tileProvider();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return TileLayer(
      urlTemplate: BaseMap._tiles,
      additionalOptions: {'style': dark ? 'grau' : 'farbe'},
      userAgentPackageName: 'de.muktadir.ruhrtransit',
      maxNativeZoom: BaseMap.maxZoom.toInt(),
      tileBuilder: dark ? darkModeTileBuilder : null,
      tileProvider: _provider,
    );
  }
}

LatLng toLatLng(GeoPoint point) => LatLng(point.latitude, point.longitude);
