# RuhrTransit

A public transport departure board for the Ruhr area (Bochum, Dortmund, VRR),
built with Flutter. Android first; iOS is planned.

**Status:** Phase 7 – search a stop or list the stops near you, and see
its live departure board (delays, cancellations, platform changes). Plan a
trip between two stops, leaving now, at a chosen time or arriving by one,
with delays, walks and the time to change. Save favourite stops for one-tap
access from the start screen. Without a connection, the last board of a
recently opened stop is shown, minus departures that have left, and marked
with when it was fetched. An Android home-screen widget shows the next
departures of one chosen stop. Refresh is manual only, as the VRR terms
allow user-triggered queries: the widget shows what the app fetched last
and never queries the server itself.

Known limits:

- Trip times are sent as picked on the phone and read by EFA as German
  local time; on a phone set to another time zone, chosen times are off by
  the difference.
- Trips start and end at stops; addresses and places are not supported.
- EFA's trip responses have not shown cancelled legs so far, so the trip
  planner does not mark them; the departure board does.

## Privacy

- **Location:** read once when the user taps "Use my location" in "Stops
  near me", never at app start or in the background. The coordinates are
  sent to the VRR server to find nearby stops and are not stored by the
  app.
- **Favourite stops and journeys, saved boards, widget data, settings
  (language, theme, optional display name):** stored on the device only.
- **No accounts yet:** `AuthRepository` has a local "signed out"
  implementation; a backend can replace it without UI changes.

The privacy policy and terms (drafts) are in `assets/legal/`, see
`docs/privacy-policy.md`; the Play Console data safety answers are in
`docs/play-console.md`.

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

Accessibility checks (every screen at 200 % font size, tap targets, labels,
contrast) run with the tests; manual checks before a release are in
`docs/accessibility.md`.

Refresh the recorded API responses used by tests:

```sh
dart run tool/capture_efa_fixtures.dart
```

Redraw the launcher icon PNGs for Android 7.1 and below after changing the
icon (`res/drawable/ic_launcher_foreground.xml`):

```sh
dart run tool/render_legacy_icons.dart
```

## Release

Create the upload key once (keep the file and passwords outside the repo,
and back them up):

```sh
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048   -validity 10000 -alias upload
```

Then create `android/key.properties` (ignored by git):

```properties
storeFile=<absolute path to upload-keystore.jks>
storePassword=<password>
keyAlias=upload
keyPassword=<password>
```

Build the bundle for the Play Console:

```sh
flutter build appbundle --release
```

Without `key.properties` the release build is signed with the debug key, so
`flutter run --release` works locally; Play rejects such a bundle. The full
checklist, including VRR production access, is in `docs/play-console.md`;
store texts are in `docs/store-listing.md`.
