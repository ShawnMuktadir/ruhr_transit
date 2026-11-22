# Privacy policy and terms

The texts live in the app, one Markdown file per language:

- `assets/legal/privacy_de.md`, `assets/legal/privacy_en.md`
- `assets/legal/terms_de.md`, `assets/legal/terms_en.md`

The app shows them under Settings > Legal. The public website in `docs/`
(GitHub Pages) is built from the same files, so the app and the website
never say different things:

```sh
dart run tool/build_legal_site.dart
```

`test/legal_site_test.dart` fails when `docs/` is out of date.

**Before publishing:**

1. There is no Impressum (decided 2026-11-22): RuhrTransit is a free,
   non-commercial hobby app, and § 5 DDG covers services offered
   commercially, usually for payment. Contact is name and email only, no
   postal address or phone. Add an Impressum with a valid postal address
   (a c/o address service keeps the home address private) before ads, a
   price, in-app purchases, donations, publishing as a company, or
   declaring yourself a trader to Apple. The repository is public: never
   commit a private home address.
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
| tracking | Analyse oder Nachverfolgung (Tracking) | Tracking |
| processed under their own responsibility | in eigener Verantwortung | als eigenständig Verantwortliche |
