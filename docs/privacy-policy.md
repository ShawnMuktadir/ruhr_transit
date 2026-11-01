# Privacy policy and terms

The texts live in the app, one Markdown file per language:

- `assets/legal/privacy_de.md`, `assets/legal/privacy_en.md`
- `assets/legal/terms_de.md`, `assets/legal/terms_en.md`

The app shows them under Settings › Legal. The Play Console needs the
privacy policy at a public URL as well; publish the same text there, so the
app and the store never say different things.

**Before publishing:**

1. Replace the placeholders in square brackets (name, address, email, date,
   link to VRR's privacy policy).
2. Have both texts checked. They are drafts that describe what the app
   does, not legal advice.
3. Remove the draft notice (the `>` block at the top of each file) and
   adjust the test in `test/features/legal/legal_test.dart` that expects it.
4. Check the facts again after every feature that sends or stores data. A
   test checks the values taken from the code (1 km radius, 10 cached
   boards, openservice.vrr.de).
