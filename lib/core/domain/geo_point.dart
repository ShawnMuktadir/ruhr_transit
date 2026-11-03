/// A point on Earth (WGS84), without depending on a map library.
class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  @override
  bool operator ==(Object other) =>
      other is GeoPoint &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'GeoPoint($latitude, $longitude)';
}

/// EFA's `[latitude, longitude]` with `coordOutputFormat=WGS84[dd.ddddd]`.
///
/// Null for anything else, also for numbers outside latitude/longitude
/// ranges: without the format EFA sends its own projection
/// (`[5257778.0, 869215.0]`), which must never land on the map.
GeoPoint? readGeoPoint(Object? json) => switch (json) {
  [final num latitude, final num longitude, ...]
      when latitude.abs() <= 90 && longitude.abs() <= 180 =>
    GeoPoint(latitude.toDouble(), longitude.toDouble()),
  _ => null,
};

/// A path of EFA points (`coords`); points that cannot be read are left out.
List<GeoPoint> readGeoPath(Object? json) => switch (json) {
  final List<Object?> points => [
    for (final point in points) ?readGeoPoint(point),
  ],
  _ => const [],
};
