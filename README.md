# RuhrTransit

A public transport departure board for the Ruhr area (Bochum, Dortmund, VRR),
built with Flutter. Android first; iOS is planned.

**Status:** Phase 2 – search a stop and see its live departure board
(delays, cancellations, platform changes). Refresh is manual only, as the
VRR terms allow user-triggered queries.

## Data source

Timetable and realtime data come from the
[VRR open service](https://www.opendata-oepnv.de/ht/de/organisation/verkehrsverbuende/vrr/openvrr/start)
(EFA, rapidJSON output), used under the OpenData ÖPNV API usage agreement.
Timetable information is provided by Verkehrsverbund Rhein-Ruhr (VRR).
All information without guarantee.

The base URL is configured in `lib/core/config/app_config.dart` and can be
overridden with `--dart-define=EFA_BASE_URL=...`.

## Development

```sh
flutter pub get          # also generates localization files
dart format lib test tool
flutter analyze
flutter test
```

Refresh the recorded API responses used by tests:

```sh
dart run tool/capture_efa_fixtures.dart
```
