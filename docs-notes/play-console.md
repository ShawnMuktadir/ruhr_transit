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
6. **Privacy policy** (`docs-notes/privacy-policy.md`, texts in `assets/legal/`):
   hosted on GitHub Pages; enter the URL under App content ›
   Privacy policy.
7. Store listing texts and graphics: `docs-notes/store-listing.md`.
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

Moved to [store-forms.md](store-forms.md), together with Apple's App
Privacy answers, content rating, target audience and the other App content
items. Keep the answers there in step with the privacy policy.

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
