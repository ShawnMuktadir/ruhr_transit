# When accounts come: what the legal texts must change

The texts in `assets/legal/` (and the website built from them in `docs/`)
say the app has no accounts and no server of its own. Before accounts,
sync or any backend ship, update at least:

- **Privacy policy**
  - Remove "no user accounts" and "no server of its own"; describe the
    account data (email, name, password handling, sign-in provider).
  - Name the backend and hosting provider (for example Firebase / Google
    Cloud), the server location, and whether data leaves the EU (transfer
    basis, such as the EU-U.S. Data Privacy Framework or standard
    contractual clauses).
  - Data processing agreement (Art. 28 GDPR) with the backend provider:
    they become a processor acting on your behalf.
  - What is synced (favourites, journeys, reminders?), retention, and how
    to delete the account and its data.
  - Legal basis for the account (Art. 6(1)(b) GDPR) and any emails sent.
  - Any analytics or crash reporting the backend SDK brings: list it, or
    keep it off.
  - Rights: now you hold data, so access and deletion requests apply to
    you directly; describe how to make them.
- **Terms**: account rules, termination, user responsibilities for their
  login.
- **In the app**: account deletion inside the app (Google Play and Apple
  both require it for apps with accounts) and a deletion web page
  (Google Play asks for a URL).
- **Store forms** (`store-forms.md`): Play Data safety (personal info,
  user IDs, possibly app activity, deletion mechanism "Yes"), Apple App
  Privacy (contact info, identifiers, linked to the user), Sign in with
  Apple if other social logins are offered.
- **Impressum**: none so far; needed (with a postal address) if the
  project becomes commercial.
- Rebuild the website: `dart run tool/build_legal_site.dart`.
