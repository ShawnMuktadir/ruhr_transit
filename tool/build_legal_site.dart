// Builds the public website in docs/ (GitHub Pages) from the legal texts in
// assets/legal/, so the app and the website always say the same:
//
//   dart run tool/build_legal_site.dart
//
// Plain HTML and CSS, no JavaScript, no external fonts. A test checks that
// docs/ matches the texts (test/legal_site_test.dart).
import 'dart:io';

/// A page of the site: its Markdown source and its file in docs/.
class SitePage {
  const SitePage(this.asset, this.file, this.language, this.counterpart);

  final String asset;
  final String file;

  /// `de` or `en`.
  final String language;

  /// The same page in the other language.
  final String counterpart;
}

const pages = [
  SitePage('privacy_en.md', 'privacy-en.html', 'en', 'privacy-de.html'),
  SitePage('privacy_de.md', 'privacy-de.html', 'de', 'privacy-en.html'),
  SitePage('terms_en.md', 'terms-en.html', 'en', 'terms-de.html'),
  SitePage('terms_de.md', 'terms-de.html', 'de', 'terms-en.html'),
  SitePage('impressum_de.md', 'impressum.html', 'de', 'impressum-en.html'),
  SitePage('impressum_en.md', 'impressum-en.html', 'en', 'impressum.html'),
];

/// Every file of the site, by name, built from [readAsset].
Map<String, String> buildSite(String Function(String asset) readAsset) => {
  'index.html': _index(),
  'style.css': _css,
  for (final page in pages) page.file: _page(page, readAsset(page.asset)),
};

void main() {
  final site = buildSite(
    (asset) => File('assets/legal/$asset').readAsStringSync(),
  );
  Directory('docs').createSync();
  for (final MapEntry(:key, :value) in site.entries) {
    File('docs/$key').writeAsStringSync(value);
  }
  // ignore: avoid_print
  print('Wrote ${site.length} files to docs/.');
}

String _page(SitePage page, String markdown) {
  final de = page.language == 'de';
  final title = RegExp(
    r'^# (.+)$',
    multiLine: true,
  ).firstMatch(markdown)!.group(1)!;
  final links = de
      ? [
          ('privacy-de.html', 'Datenschutz'),
          ('terms-de.html', 'Nutzungsbedingungen'),
          ('impressum.html', 'Impressum'),
        ]
      : [
          ('privacy-en.html', 'Privacy'),
          ('terms-en.html', 'Terms'),
          ('impressum-en.html', 'Legal notice'),
        ];
  return _document(
    language: page.language,
    title: '$title - RuhrTransit',
    body:
        '''
<header>
  <a class="home" href="index.html">RuhrTransit</a>
  <a class="language" href="${page.counterpart}" hreflang="${de ? 'en' : 'de'}" lang="${de ? 'en' : 'de'}">${de ? 'English' : 'Deutsch'}</a>
</header>
<main>
${markdownToHtml(markdown)}
</main>
<footer>
  <nav>${[for (final (href, label) in links) '<a href="$href">$label</a>'].join(' · ')}</nav>
</footer>''',
  );
}

String _index() => _document(
  language: 'en',
  title: 'RuhrTransit',
  body: '''
<main>
<h1>RuhrTransit</h1>
<p>A free app for public transport in the Ruhr area and across Germany: departures, stops nearby and trips, with data from the Verkehrsverbund Rhein-Ruhr (VRR). No account, no ads, no tracking. Not an app of VRR.</p>
<section lang="en">
<h2>English</h2>
<ul>
<li><a href="privacy-en.html">Privacy policy</a></li>
<li><a href="terms-en.html">Terms and conditions</a></li>
<li><a href="impressum-en.html">Legal notice (Impressum)</a></li>
</ul>
</section>
<section lang="de">
<h2>Deutsch</h2>
<p>Eine kostenlose App für Bus und Bahn im Ruhrgebiet und in ganz Deutschland: Abfahrten, Haltestellen in der Nähe und Verbindungen, mit Daten des Verkehrsverbunds Rhein-Ruhr (VRR). Kein Benutzerkonto, keine Werbung, kein Tracking. Keine App des VRR.</p>
<ul>
<li><a href="privacy-de.html">Datenschutzerklärung</a></li>
<li><a href="terms-de.html">Nutzungsbedingungen</a></li>
<li><a href="impressum.html">Impressum</a></li>
</ul>
</section>
</main>''',
);

String _document({
  required String language,
  required String title,
  required String body,
}) =>
    '''
<!doctype html>
<html lang="$language">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<title>${_escape(title)}</title>
<link rel="stylesheet" href="style.css">
</head>
<body>
$body
</body>
</html>
''';

/// The Markdown the legal texts use: headings, paragraphs, bullets, a
/// callout (`>`), bold, and plain links and email addresses.
String markdownToHtml(String markdown) {
  final out = <String>[];
  var paragraph = <String>[];
  var bullets = <String>[];
  var callout = <String>[];

  void flush() {
    if (paragraph.isNotEmpty) out.add('<p>${_inline(paragraph.join(' '))}</p>');
    if (callout.isNotEmpty) {
      out.add('<p class="draft">${_inline(callout.join(' '))}</p>');
    }
    if (bullets.isNotEmpty) {
      out.add(
        '<ul>\n${bullets.map((b) => '<li>${_inline(b)}</li>').join('\n')}\n</ul>',
      );
    }
    paragraph = [];
    bullets = [];
    callout = [];
  }

  for (final raw in markdown.split('\n')) {
    final line = raw.trim();
    final heading = RegExp(r'^(#{1,3})\s+(.*)$').firstMatch(line);
    if (line.isEmpty) {
      flush();
    } else if (heading != null) {
      flush();
      final level = heading.group(1)!.length;
      out.add('<h$level>${_inline(heading.group(2)!)}</h$level>');
    } else if (line.startsWith('- ')) {
      if (paragraph.isNotEmpty || callout.isNotEmpty) flush();
      bullets.add(line.substring(2));
    } else if (line.startsWith('>')) {
      callout.add(line.substring(1).trim());
    } else if (bullets.isNotEmpty) {
      bullets.last = '${bullets.last} $line';
    } else {
      paragraph.add(line);
    }
  }
  flush();
  return out.join('\n');
}

String _inline(String text) {
  var html = _escape(text);
  html = html.replaceAllMapped(
    RegExp(r'\*\*(.+?)\*\*'),
    (m) => '<strong>${m[1]}</strong>',
  );
  html = html.replaceAllMapped(
    RegExp(r'https?://[^\s<]+[^\s<.,;:)]'),
    (m) => '<a href="${m[0]}">${m[0]}</a>',
  );
  html = html.replaceAllMapped(
    RegExp(r'[\w.+-]+@[\w-]+\.[\w.]+[\w]'),
    (m) => '<a href="mailto:${m[0]}">${m[0]}</a>',
  );
  // Placeholders the owner still has to fill in, easy to spot.
  html = html.replaceAllMapped(
    RegExp(r'\[(PLATZHALTER|PLACEHOLDER):[^\]]*\]'),
    (m) => '<mark>${m[0]}</mark>',
  );
  return html;
}

String _escape(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

const _css = '''
:root {
  color-scheme: light dark;
  --text: #1b1c1f;
  --muted: #4a4d55;
  --background: #fbfbfd;
  --card: #eef0f6;
  --accent: #2f5aa8;
  --draft: #fff4d6;
  --draft-border: #d9a400;
}
@media (prefers-color-scheme: dark) {
  :root {
    --text: #e4e5ea;
    --muted: #b4b7c0;
    --background: #121316;
    --card: #1f2127;
    --accent: #9dbbff;
    --draft: #3a3112;
    --draft-border: #c99a12;
  }
}
* { box-sizing: border-box; }
body {
  margin: 0;
  background: var(--background);
  color: var(--text);
  font: 17px/1.6 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
}
header, main, footer { max-width: 44rem; margin: 0 auto; padding: 0 16px; }
header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding-top: 16px;
  padding-bottom: 8px;
}
.home { font-weight: 700; text-decoration: none; }
a { color: var(--accent); overflow-wrap: anywhere; }
h1 { font-size: 1.8rem; line-height: 1.25; margin: 1rem 0; }
h2 { font-size: 1.3rem; margin: 2rem 0 0.5rem; }
h3 { font-size: 1.1rem; margin: 1.5rem 0 0.25rem; }
ul { padding-left: 1.25rem; }
li { margin: 0.4rem 0; }
.draft {
  background: var(--draft);
  border-left: 4px solid var(--draft-border);
  padding: 12px 16px;
  border-radius: 8px;
}
mark { background: var(--draft); color: var(--text); padding: 0 4px; border: 1px dashed var(--draft-border); }
footer { padding-top: 24px; padding-bottom: 32px; color: var(--muted); }
footer nav { border-top: 1px solid var(--card); padding-top: 16px; }
''';
