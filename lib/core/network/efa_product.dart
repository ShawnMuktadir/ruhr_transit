import 'package:ruhr_transit/core/domain/transport_mode.dart';

/// EFA product classes, verified against `transportation.product` in the
/// departure and trip fixtures. Classes seen on stops but not verified
/// (0, 7, 17) are intentionally missing.
const _modesByProductClass = {
  1: TransportMode.suburbanTrain, // S-Bahn
  2: TransportMode.subway, // U-Bahn (Stadtbahn)
  4: TransportMode.tram, // Straßenbahn
  5: TransportMode.bus, // Bus, Niederflurbus
  13: TransportMode.train, // RE, Regionalzug
  16: TransportMode.train, // ICE, Zug
};

/// The mode for an EFA product class, or null if the class is unknown.
TransportMode? transportModeForProductClass(Object? productClass) =>
    _modesByProductClass[productClass];
