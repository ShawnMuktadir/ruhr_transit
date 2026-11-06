# Privacy policy and terms

The texts live in the app, one Markdown file per language:

- `assets/legal/privacy_de.md`, `assets/legal/privacy_en.md`
- `assets/legal/terms_de.md`, `assets/legal/terms_en.md`

The app shows them under Settings › Legal. The Play Console needs the
privacy policy at a public URL as well; publish the same text there, so the
app and the store never say different things.

**Before publishing:**

1. Add the postal address, which is still missing from all four texts, and
   set the real date: the "last updated" date (November 10, 2026) is
   provisional.
2. Have both texts checked. They are drafts that describe what the app
   does, not legal advice.
3. Remove the draft notice (the `>` block at the top of each file) and
   adjust the test in `test/features/legal/legal_test.dart` that expects it.
4. Check the facts again after every feature that sends or stores data. A
   test checks the values taken from the code (1 km radius, 10 cached
   boards, openservice.vrr.de).
