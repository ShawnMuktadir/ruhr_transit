# iPhone builds through TestFlight

The iPhone app is built and uploaded by GitHub Actions on a Mac
(`.github/workflows/testflight.yml`), so no Mac is needed. TestFlight then
installs it on iPhones (and on iPads, as an iPhone app).

## One-time setup

### 1. App ID
[developer.apple.com](https://developer.apple.com/account) > Certificates,
IDs & Profiles > Identifiers > **+** > App IDs > App:

- Description: `RuhrTransit`
- Bundle ID: **Explicit**, `de.muktadir.ruhrtransit`
- Capabilities: none extra (reminders are local notifications, which need
  no push capability)

### 2. App in App Store Connect
[appstoreconnect.apple.com](https://appstoreconnect.apple.com) > Apps >
**+** > New App:

- Platform: iOS
- Name: `RuhrTransit` (must be unique in the App Store; if taken, e.g.
  `RuhrTransit – Bus & Bahn`)
- Primary language: German
- Bundle ID: `de.muktadir.ruhrtransit`
- SKU: `ruhrtransit`
- User access: Full access

### 3. Distribution certificate
Needs a certificate signing request (CSR), made with OpenSSL on Windows;
its private key never leaves this laptop and the GitHub secret.

Certificates > **+** > **Apple Distribution** > upload
`RuhrTransit.certSigningRequest` > download `distribution.cer`.

The certificate and the private key are then packed into a `.p12` file
with a random password:

```sh
openssl x509 -inform DER -in distribution.cer -out distribution.pem
openssl pkcs12 -export -legacy -inkey distribution.key -in distribution.pem \
  -out distribution.p12 -passout file:p12_password.txt
```

(`-legacy`: the macOS keychain does not read OpenSSL 3's newer default
encryption.)

### 4. Provisioning profile
Profiles > **+** > Distribution: **App Store Connect** > App ID
`de.muktadir.ruhrtransit` > the certificate from step 3 > name it exactly
**`RuhrTransit App Store`** (the workflow looks for this name) > download.

### 5. App Store Connect API key
Users and Access > Integrations > App Store Connect API > Team Keys >
**+**: name `GitHub TestFlight`, access **App Manager**. Note the
**Issuer ID** (above the list) and the **Key ID**, and download the `.p8`
file. It can be downloaded only once.

### 6. GitHub secrets
Repository > Settings > Secrets and variables > Actions > New repository
secret, one each:

| Secret | Value |
|---|---|
| `APPLE_TEAM_ID` | Team ID, 10 characters (developer.apple.com > Membership details) |
| `IOS_DIST_CERT_P12` | `distribution.p12`, base64-encoded |
| `IOS_DIST_CERT_PASSWORD` | contents of `p12_password.txt` |
| `IOS_PROFILE` | the profile from step 4, base64-encoded |
| `ASC_KEY_ID` | Key ID from step 5 |
| `ASC_ISSUER_ID` | Issuer ID from step 5 |
| `ASC_KEY_P8` | the `.p8` file from step 5, base64-encoded |

Base64 on Windows (Git Bash): `base64 -w0 file > file.b64`, then paste the
contents of the `.b64` file. Never commit these files or paste them
anywhere else.

## Each new build
1. Actions > **TestFlight** > Run workflow (on `main`).
2. After about 10 to 30 minutes Apple has processed the build: App Store
   Connect > the app > TestFlight.
3. The first time: TestFlight > Internal Testing > **+** to make a group,
   add yourself as a tester. Install **TestFlight** from the App Store on
   the iPhone and iPad and accept the invitation; later builds arrive
   there by themselves.

The build number is the workflow's run number; the version comes from
`pubspec.yaml`. Internal testers need no review by Apple; external testers
(people outside the developer account) need a short beta review and a
privacy policy URL.

## Renewal
The certificate and the profile expire after a year. Then repeat steps 3,
4 and the matching secrets.
