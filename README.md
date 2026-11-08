# RuhrTransit

See when buses and trains in the Ruhr area really leave, and plan trips across
Germany. No sign-up, no ads, no tracking.

An Android app built with Flutter, in German and English, with light and dark
themes.

**Status:** in development, not yet on the Play Store. Before release it needs
production access from VRR, an upload key, store graphics, and finished legal
texts (see [Release](#release)).

## Features

**Departures**
- Live board for any stop, with delays, cancellations and platform changes
- Stops near you, as a list or on a map, filtered by type of transport
- A home-screen widget with the next departures of one chosen stop

**Trips**
- From and to stops, addresses and places: leave now, depart at or arrive by a
  time
- Start from your current location
- Walks with directions, lifts and stairs, and the time to change between rides
- Where your train is now, along its run
- Notices and disruptions, the important ones first
- Trips on a map

**Staying on time**
- Reminders 5 to 30 minutes before a ride, for trips and departures, updated
  with the current delay. They also work with the app closed
- Weather at your location on the planner, with a hint when rain or snow is
  coming, and a background that follows the sky

**Everyday use**
- Favourite stops and saved journeys, plus a search history
- Without a connection, the last loaded departures stay visible with the time
  they were fetched, and the app reloads when it is back online
- Accessibility: TalkBack labels, large text and "Remove animations" are
  supported

## Getting started

You need Flutter 3.41.2 (the version CI uses) and the Android SDK. The app
supports Android 7.0 (API 24) and newer. iOS is not supported.

```sh
flutter pub get    # also generates the localization files
flutter run
```

No API key is needed. Location, notifications and exact alarms are requested
only for the features that use them.

## Development

Run these before pushing; CI runs the same three:

```sh
dart format lib test tool
flutter analyze
flutter test
```

The tests include accessibility checks of every screen, in light and dark, at
100, 130 and 200 % text size. Manual checks before a release are in
[docs/accessibility.md](docs/accessibility.md).

### Project layout

```text
lib/
  core/       shared code: network, theme, map, widgets, localization
  features/   one folder per feature, split into data, domain and presentation
android/      Android code for the widget, connectivity and app language
assets/legal/ privacy policy and terms, one file per language
docs/         release checklist, store texts, privacy and accessibility notes
tool/         scripts, see below
```

State lives in `flutter_bloc` cubits with sealed states. `get_it` is used only
where the app is put together. Text comes from the ARB files in
`lib/core/l10n/arb`, where German is the template.

### Scripts

```sh
# Refresh the recorded API responses used by tests
dart run tool/capture_efa_fixtures.dart

# Redraw the launcher PNGs for Android 7.1 and below and the iPhone app
# icons after changing res/drawable/ic_launcher_foreground.xml
dart run tool/render_icons.dart

# Regenerate the database code after changing its tables
dart run build_runner build
```

## Data sources

| Data | Source | Terms |
|---|---|---|
| Timetable and realtime | [VRR open service](https://www.opendata-oepnv.de/ht/de/organisation/verkehrsverbuende/vrr/openvrr/start) (EFA, rapidJSON) | OpenData ÖPNV usage agreement: live, user-triggered queries only, no bulk use |
| Weather | [Bright Sky](https://brightsky.dev), serving Deutscher Wetterdienst open data | Germany only |
| Maps | [basemap.de](https://basemap.de) by BKG | CC BY 4.0, © GeoBasis-DE / BKG |

Timetable information is provided by Verkehrsverbund Rhein-Ruhr (VRR). All
information without guarantee. RuhrTransit is not an app of VRR.

Departures refresh only when the user asks, as the VRR terms require. The widget
shows what the app fetched last. The one request without a tap at that moment is
for a reminder the user has set: when it is due, the app asks VRR for the ride's
delay.

Both base URLs are in `lib/core/config/app_config.dart` and can be overridden:

```sh
flutter run --dart-define=EFA_BASE_URL=https://openservice-test.vrr.de/openservice
flutter run --dart-define=BRIGHT_SKY_BASE_URL=<url>
```

## Privacy

The app has no accounts and no analytics.

- **Sent to VRR:** search terms, which can include a home address, the chosen
  stops and times, your coordinates when you ask for stops near you or start
  from your location, and the ride's details for a reminder.
- **Sent to Bright Sky:** your coordinates, rounded to about 1 km, for the
  weather.
- **Sent to basemap.de:** the map area shown, through the map images requested.
- **Stored on the device only:** favourites, search history (last 10), reminders,
  saved departures, widget data, map images (at most 100 MB) and settings.

The full texts are in `assets/legal/`, shown in the app under Settings › Legal.
They are still drafts, see [docs/privacy-policy.md](docs/privacy-policy.md).

## Known limits

- Trips with neither end in NRW are sometimes very slow. On one evening Berlin
  to Passau took 111 s and Hamburg to Freiburg got no answer in 150 s, while
  trips with an NRW end stayed fast; later the same kind of trips took 4 to
  20 s. The app waits up to 2 minutes for these instead of 15 seconds, and says
  so.
- Trip times are sent as picked on the phone and read by the timetable service
  as German local time. On a phone set to another time zone, chosen times are off
  by the difference.
- The timetable service has not shown cancelled legs in trip responses so far,
  so the trip planner does not mark them. The departure board does.
- Some long-distance trains arrive with no line name, and show as "Zug".
- Weather and maps cover Germany only.

## Release

The full checklist, including VRR production access, is in
[docs/play-console.md](docs/play-console.md). Store texts are in
[docs/store-listing.md](docs/store-listing.md).

Create the upload key once. Keep the file and passwords outside the repository,
and back them up:

```sh
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Then create `android/key.properties`, which git ignores:

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

Without `key.properties`, the release build is signed with the debug key. That
works locally, but Play rejects it.
