# Store forms: draft answers

Draft answers for Google Play and the App Store, for the app as it is on
2026-11-22: no accounts, no analytics, no ads. Not legal advice; check
each answer against the current form before submitting. This file is not
published (only `docs/` is).

Definitions used below, checked on the official pages on 2026-11-22:

- **Google Play**: "'Collect' means transmitting data from your app off a
  user's device", also when it goes to a third-party server. "'Sharing'
  refers to transferring user data collected from your app to a third
  party." Not sharing: service providers acting on your instructions, and
  "transferring user data to a third party based on a specific
  user-initiated action, where the user reasonably expects the data to be
  shared". Data processed **ephemerally** (only in memory, kept no longer
  than needed for the request) must still be entered in the form, but is
  then not shown on the store page.
- **Apple**: "'Collect' refers to transmitting data off the device in a
  way that allows you and/or your third-party partners to access it for a
  period longer than what is necessary to service the transmitted request
  in real time." "Third-party partners" are "analytics tools, advertising
  networks, third-party SDKs, or other external vendors whose code you've
  added to your app". **Precise Location**: three or more decimal places
  of latitude and longitude; **Coarse Location**: fewer.

## Facts the answers rest on

| What leaves the device | To | When | Precision |
|---|---|---|---|
| Search text (can be a home address), chosen stops, trip times | VRR (openservice.vrr.de) | user searches | - |
| Coordinates for "Stops near me" | VRR | tap the first time, then each time the tab opens once allowed | full (precise) |
| Coordinates for "Use current location as start" / "Walk to ..." | VRR | tap | 4 decimals, about 10 m (precise) |
| Coordinates for the weather | Bright Sky (api.brightsky.dev) | automatically when the planner opens, if location is allowed | 2 decimals, about 1 km (coarse) |
| Map area shown | BKG (basemap.de) | while a map is open | area of the map (around the user on the nearby map) |
| Line, trip and stop of a reminder | VRR | Android only, when the reminder is due, app may be closed | - |
| VRR notice text | Google Translate (app or browser) | tap "Translate" | - (no user data) |
| IP address | all of the above | every request | - |

All requests use HTTPS. Nothing goes to a server of the developer. No SDK
collects data (checked in `pubspec.lock`).

## Google Play: Data safety

### Overview questions

- Does your app collect or share any of the required user data types?
  **Yes** (location and search history leave the device).
- Is all of the user data collected by your app encrypted in transit?
  **Yes**.
- Do you provide a way for users to request that their data is deleted?
  **No**: the developer holds no user data. Data on the device is deleted
  by the user in the app, by clearing storage or by uninstalling. (If the
  form insists, describe this in the privacy policy, which it does.)

### Data types

| Data type | Collected | Shared | Ephemeral | Required or optional | Purpose |
|---|---|---|---|---|---|
| Location > Precise location | Yes | see below | Yes (by the app) | Optional | App functionality |
| Location > Approximate location | Yes | see below | Yes (by the app) | Optional | App functionality |
| App activity > In-app search history | Yes | see below | Yes (by the app) | Required to search | App functionality |
| Personal info > Address | Yes | No | Yes (by the app) | Optional | App functionality |

Not collected: other personal info (name, email),
financial info, health, messages, photos, audio, files, calendar,
contacts, app interactions, installed apps, web browsing, crash logs,
diagnostics, device or other IDs. The display name, favourites and search
history list stay on the device, so they are not "collected".

**Search history:** Google's "in-app search history" means searches made
in the app. Search text leaves the device to answer the search, so it is
collected. A typed home address is part of that search text; it is not a
separate "Address" profile field, so "Personal info > Address" is not
strictly needed. Decided: declare Address anyway (optional, not shared,
App functionality), because users may type their own home address and
over-declaring does no harm.

**Shared or not?** VRR, Bright Sky and BKG are independent services, not
service providers acting on the developer's instructions.

- Location to VRR for "Stops near me", "Use current location as start" and
  "Walk to ...": started by the user, who expects it to be used to find
  stops. This fits the user-initiated exception, so **not shared** is
  defensible. However, once the permission is granted, "Stops near me"
  reads the location every time the tab opens, without a separate tap.
- Location to Bright Sky for the weather: **automatic** when the planner
  opens. This does not clearly fit the user-initiated exception.
- Map area to BKG: follows from showing a map the user opened.

**Recommendation:** declare **Location (precise and approximate) as
shared**, purpose App functionality. It is the cautious answer, and Google
accepts over-declaring. Declare search history as **not shared** (sent
only when the user searches, to get the answer). Flag: ask yourself
whether you want to change the weather to ask once before the first
automatic use; that would make "not shared" easier to argue.

**Ephemeral:** the app itself keeps nothing off the device, but VRR,
Bright Sky and BKG may log requests. Google's ephemeral rule is about how
the data is processed after collection. Answering "Yes" is reasonable for
the app's own handling; if unsure, answer "No", which only makes the
store page show more, never less.

### Other Play Console items

- **Privacy policy URL**: Play Console > Policy and programs > App content >
  Privacy policy: `https://shawnmuktadir.github.io/ruhr_transit/privacy-en.html`
  (Play shows one URL; the English page links to German.)
- **Ads**: App content > Ads: **No, my app does not contain ads**.
- **App access**: **All functionality is available without special
  access** (no login).
- **Target audience and content**: choose **18 and over** (or 16 and over).
  Do not include ages under 13: that brings the Families policy into play.
  The app is not designed for children.
- **Content rating** (IARC questionnaire): category Reference, News, or
  Educational / Utility, Productivity, Communication or Other. No violence,
  sex, language, drugs, gambling; no user-generated content; no user
  interaction or chat; no digital purchases. Answer "Yes" where it asks if
  the app **shares the user's location with third parties** (VRR, Bright
  Sky, BKG); it does not share it with other users.
- **Account deletion**: not applicable, the app has no accounts. The form
  only asks when the app lets users create an account.
- **News app**: No. **Government app**: No. **Health app**: No.
  **Financial features**: None.
- **Location permission**: foreground only, no background location, so no
  background location declaration is needed.
- **Exact alarms**: `SCHEDULE_EXACT_ALARM` for reminders; check the
  current exact-alarm policy and declaration in Play Console.
- **Developer contact**: Google Play shows the developer's email, and for
  some accounts the address, publicly on the store page.

## Apple: App Privacy ("nutrition label")

Apple asks per data type whether you or your **third-party partners**
collect it. Partners are vendors **whose code you added** to the app.
RuhrTransit adds no SDK that sends data; it calls the public APIs of VRR,
Bright Sky and BKG directly.

Two readings:

1. **Strict reading: "Data Not Collected."** The data goes to services
   that are not partners in Apple's sense, and the developer cannot access
   it at all. This fits the wording, but the services may keep logs that
   neither Apple nor you can see.
2. **Cautious reading: declare it.**
   - **Location > Precise Location**: App Functionality; **not linked** to
     the user's identity; **not used for tracking**.
   - **Location > Coarse Location** (weather, 2 decimals): same answers.
   - **Search History**: App Functionality; not linked; not tracking.
   - **Contact Info > Physical Address**: same answers; a search can
     contain a home address (matches the Address answer on Google Play).

**Recommendation:** the cautious reading. Location is part of the app's
main features, and after the permission is granted it is used on an
ongoing basis, which Apple's optional-disclosure rule excludes ("data
collected on an ongoing basis after an initial request for permission
must be disclosed"). Over-declaring causes no rejection; under-declaring
can.

- **Tracking**: **No**. No data is linked with third-party data for ads
  and nothing goes to data brokers. No App Tracking Transparency prompt is
  needed.
- **Linked to you**: **No**. There is no account, name or ID sent along.
  Note: Apple treats "personal data" under privacy laws as linked; an IP
  address is personal data under the GDPR, but Apple's own example says an
  IP address sent and not kept need not be disclosed. Flag for review.
- **Privacy Policy URL**: App Store Connect > your app > App Privacy >
  Privacy Policy URL:
  `https://shawnmuktadir.github.io/ruhr_transit/privacy-en.html`.
  Optional "User Privacy Choices URL": leave empty.
- **Support URL** (required, App Store > version information):
  `https://shawnmuktadir.github.io/ruhr_transit/` (the index page).
- **Privacy manifest**: the app has no `ios/Runner/PrivacyInfo.xcprivacy`.
  Apple requires reasons for "required reason APIs" (for example
  UserDefaults, used by shared_preferences, and file timestamps). Current
  plugin versions ship their own manifests; check the App Store Connect
  warnings after the first upload and add an app-level manifest if asked.
- **Age rating**: 4+ (no objectionable content). Location use does not
  change it.
- **Sign in with Apple / account deletion**: not applicable while there
  are no accounts.
- **Developer contact**: Apple shows the seller name (your legal name for
  an individual account) and, for EU users under the Digital Services Act,
  asks traders to publish an address, phone and email. Decide whether you
  are a "trader" (free app, no income: usually not) when App Store Connect
  asks.

## Decisions (2026-11-22)

1. Google Play: declare **Location (precise and approximate) as shared**,
   purpose App functionality, optional. Search history and Address:
   collected, not shared.
2. Apple: the **cautious declaration**: Precise Location, Coarse
   Location, Search History and Physical Address, App Functionality, not
   linked to the user, not used for tracking.
3. Google Play: **declare Personal info > Address** (optional, not shared,
   App functionality), since a search can contain a home address.
4. Bright Sky: **acceptable as it is.** The privacy policy names it, says
   it has no privacy policy of its own, and the app sends only
   coordinates rounded to about 1 km. No contact with the operator
   needed for now.
5. No Impressum for now (free, non-commercial). On Apple, declare
   "non-trader" under the Digital Services Act; on Google Play, keep the
   account personal and non-monetised so no address is shown. Revisit
   both, and add an Impressum, if the app ever earns money.
