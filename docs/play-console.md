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
6. **Privacy policy** (`docs/privacy-policy.md`): fill in the placeholders,
   host it, enter the URL under App content › Privacy policy.
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
with a third party (see below); no digital purchases.

**News app:** No. **Government app:** No. **Health app:** No.

## Data safety

Data sent off the device always goes to the VRR timetable service over
HTTPS. The app has no servers of its own and no SDKs that collect data.

| Data type | Collected / shared | Why | Notes |
|---|---|---|---|
| Location › Approximate location | Collected, shared with VRR | App functionality | Optional ("Stops near me" only); not stored; processed ephemerally |
| Location › Precise location | Collected, shared with VRR | App functionality | Same as above |
| App activity › In-app search history | Collected, shared with VRR | App functionality | Stop search terms are sent to find stops; not stored by the app |

- Data is encrypted in transit: **Yes** (HTTPS only).
- Users can request deletion: the app stores nothing off the device;
  favourites and cached boards are deleted with the app.
- Not collected: personal info, financial info, contacts, messages, photos,
  files, health, device IDs, crash logs, diagnostics, analytics.

Whether sending data to VRR counts as "shared" depends on Google's current
definitions (a provider acting on your behalf is not "sharing"; VRR is an
independent service). Declaring it as shared is the cautious choice.

## Permissions to justify

- `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`: find stops near the
  user, requested only when "Stops near me" is opened; no background
  location.
- `INTERNET`: timetable queries.
