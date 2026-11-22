# Privacy policy, terms and Impressum

The texts live in the app, one Markdown file per language:

- `assets/legal/privacy_de.md`, `assets/legal/privacy_en.md`
- `assets/legal/terms_de.md`, `assets/legal/terms_en.md`
- `assets/legal/impressum_de.md`, `assets/legal/impressum_en.md`

The app shows them under Settings > Legal. The public website in `docs/`
(GitHub Pages) is built from the same files, so the app and the website
never say different things:

```sh
dart run tool/build_legal_site.dart
```

`test/legal_site_test.dart` fails when `docs/` is out of date.

**Before publishing:**

1. Fill in the Impressum placeholders (postal address). Contact is by
   email only, no phone number. Check whether you need an Impressum and which address you
   are comfortable publishing; the repository and the website are public.
2. Have the texts checked. They describe what the app does; they are not
   legal advice and have not been checked by a lawyer.
3. Update the date under the title ("Last updated" / "Stand") in the
   privacy policy and the terms after each change. Remove
   `<meta name="robots" content="noindex">` in `tool/build_legal_site.dart`
   if the pages may be found by search engines.
4. Rebuild `docs/` and check the facts again after every feature that
   sends or stores data. Store answers: `store-forms.md`. Accounts later:
   `accounts-todo.md`.

**Translation choices** made in the German texts (change if you prefer):

| English | German used | Alternatives |
|---|---|---|
| controller | Verantwortlicher | Verantwortliche Stelle |
| legal basis | Rechtsgrundlage | - |
| terms and conditions | Nutzungsbedingungen | Nutzungsbedingungen und Haftungshinweise |
| legal notice | Impressum | Anbieterkennzeichnung |
| tracking | Analyse oder Nachverfolgung (Tracking) | Tracking |
| processed under their own responsibility | in eigener Verantwortung | als eigenständig Verantwortliche |
