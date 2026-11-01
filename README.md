# RuhrTransit

A public transport departure board for the Ruhr area (Bochum, Dortmund, VRR),
built with Flutter. Android first; iOS is planned.

**Status:** Phase 6 – search a stop or list the stops near you, and see
its live departure board (delays, cancellations, platform changes). Save
favourite stops for one-tap access from the start screen. Without a
connection, the last board of a recently opened stop is shown, minus
departures that have left, and marked with when it was fetched. An Android
home-screen widget shows the next departures of one chosen stop. Refresh is
manual only, as the VRR terms allow user-triggered queries: the widget shows
what the app fetched last and never queries the server itself.

## Privacy

- **Location:** read once when the user opens "Stops near me", never at app
  start or in the background. The coordinates are sent to the VRR server
  to find nearby stops and are not stored by the app. For the Play Console
  data safety form: approximate and precise location, collected (not
  optional for this feature), shared with VRR for app functionality, not
  stored, no tracking.
- **Favourites, saved boards, widget data:** stored on the device only.

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
