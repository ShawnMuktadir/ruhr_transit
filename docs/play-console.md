# Play Console: release checklist and form answers

Answers below describe what the app does as built. Check them against the
current Play Console wording before submitting; the forms change.

## Release checklist

1. **Production access to the VRR API.** The OpenData ÖPNV terms require
   asking for production use: email opendata-oepnv@vrr.de with the app name,
   purpose and expected request volume (user-triggered only). Wait for the
   answer before publishing.
2. **Upload key** (once): see README › Release. Back up the keystore and its
   passwords outside the repository; losing them means asking Google to
   reset the upload key.
3. **Version:** raise the build number (`version: 1.0.0+N` in `pubspec.yaml`)
   for every upload.
4. **Build:** `flutter build appbundle --release`
5. **Check the signer** – a bundle built without `key.properties` is
   debug-signed:
   `keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab`
   must show your upload certificate, not `CN=Android Debug`.
6. **Privacy policy** (`docs/privacy-policy.md`, texts in `assets/legal/`):
   fill in the placeholders, host it, enter the URL under App content ›
   Privacy policy.
7. Store listing texts and graphics: `docs/store-listing.md`.
8. Start with an **internal testing** track, install from Play on a real
   phone, then go through the manual checks from the phase PRs (offline
   board, widget, location permission, trip planner, German texts).

## App content

**Ads:** No.

**App access:** All functionality is available without login or special
access.

**Target audience:** 13 and over (not designed for children; no content
reason, but avoids the Families policy requirements).

**Content rating questionnaire:** category "Utility, Productivity,
Communication or Other"; no violence, sexual content, profanity, drugs,
gambling; no user-generated content or user interaction; shares location
with third parties (VRR, Bright Sky; see below); no digital purchases.

**News app:** No. **Government app:** No. **Health app:** No.

## Data safety

Data sent off the device goes over HTTPS to two services: the VRR
timetable service (openservice.vrr.de) and, for the weather, Bright Sky
(api.brightsky.dev, Deutscher Wetterdienst open data). The app has no
servers of its own and no SDKs that collect data.

| Data type | Collected / shared | Why | Notes |
|---|---|---|---|
| Location › Approximate location | Collected, shared with VRR and Bright Sky | App functionality | Optional, only with the location permission; not stored; processed ephemerally. Weather: rounded to ~1 km, sent to Bright Sky when "Plan trip" opens. |
| Location › Approximate location (map) | Shared with BKG (basemap.de) | App functionality | Only while a map is open: the tile requests show the area around the user ("Stops near me" map) |
| Location › Precise location | Collected, shared with VRR | App functionality | Optional: "Stops near me", "Use current location as start", "Walk there" and "Walk to …" on a trip (rounded to ~10 m); not stored |
| App activity › In-app search history | Collected, shared with VRR | App functionality | Search terms for stops, addresses and places are sent to find them; not stored off the device |

The search terms can be home addresses: a user may type their own street
and house number under From/To. They are only used to answer the search.

- Data is encrypted in transit: **Yes** (HTTPS only).
- Users can request deletion: the app stores nothing off the device;
  favourites, saved journeys, search history, cached boards and settings
  are deleted with the app.
- Not collected: personal info, financial info, contacts, messages, photos,
  files, health, device IDs, crash logs, diagnostics, analytics. The
  optional display name in Settings › Profile and the search history (the
  last 10 stops, addresses or places chosen for From/To) stay on the device, so they are not
  "collected" in Google's sense. Revisit this once accounts exist.

Whether sending data to VRR and Bright Sky counts as "shared" depends on
Google's current definitions (a provider acting on your behalf is not
"sharing"; both are independent services). Declaring it as shared is the
cautious choice.

**Bright Sky publishes no privacy policy of its own** (checked 2026-11-03:
brightsky.dev links only to the DWD's legal notice and an email contact).
Before publishing, decide with legal advice whether that is acceptable or
ask the operator; the privacy text links to brightsky.dev until then.

## Permissions to justify

- `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`: find stops near the
  user, start a trip at the current location, and show the weather there.
  Requested only after a tap ("Use my location", the location button in
  From, or the weather chip); no background location.
- `INTERNET`: timetable and weather queries.
- `POST_NOTIFICATIONS`: departure reminders the user sets on a trip; asked
  for when setting the first one.
- `SCHEDULE_EXACT_ALARM`: optional, so reminders come on time; without it
  they may be some minutes late. Android 14+ denies it by default and the
  user can allow it from the app. Check Play's current exact-alarm policy
  before submitting.
- `RECEIVE_BOOT_COMPLETED`, `WAKE_LOCK`: keep reminders across a reboot and
  check the delay while the app is closed.
- `ACCESS_NETWORK_STATE`: show "no internet connection" and retry when the
  connection returns (normal permission, granted at install).
