/// The single place for runtime configuration.
///
/// Values can be overridden at build time without code changes, e.g.
/// `flutter run --dart-define=EFA_BASE_URL=https://openservice-test.vrr.de/openservice`.
///
/// Pure Dart (no Flutter import) so that scripts in `tool/` can reuse it.
abstract final class AppConfig {
  /// Base URL of the VRR EFA open service (rapidJSON output).
  static const String efaBaseUrl = String.fromEnvironment(
    'EFA_BASE_URL',
    defaultValue: 'https://openservice.vrr.de/openservice',
  );

  /// Bright Sky, which serves Deutscher Wetterdienst open data.
  static const String brightSkyBaseUrl = String.fromEnvironment(
    'BRIGHT_SKY_BASE_URL',
    defaultValue: 'https://api.brightsky.dev',
  );

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 15);

  /// For a trip with neither end in NRW: VRR's service is sometimes far
  /// slower for those (measured one evening: Berlin to Munich 50 s, Berlin to
  /// Passau 111 s; on other days 4 to 20 s).
  static const Duration outsideNrwTimeout = Duration(minutes: 2);
}
