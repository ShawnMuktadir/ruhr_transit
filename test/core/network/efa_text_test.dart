import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/network/efa_text.dart';

void main() {
  group('efaPlainText', () {
    test('leaves plain text as it is', () {
      expect(
        efaPlainText(
          'An der Haltestelle Bochum Hbf ist der Aufzug außer '
          'Betrieb.',
        ),
        'An der Haltestelle Bochum Hbf ist der Aufzug außer Betrieb.',
      );
    });

    test('turns blocks into lines and drops other markup', () {
      // Shortened from a recorded lineInfo notice.
      const html = '''
<p>

        Linien 345, 355:
Zwischen <b>(H) Bochum, Lessing-Schule</b> und <b>(H) Sportplatz</b>.
<p>
Dauer: 08.06.26 bis 04.01.27
<p><h2 style="text-align: center;"><strong>Umbau</strong></h2>
<div>&nbsp;</div>
<div><strong>Beginn:</strong> Montag</div><div>&nbsp;</div><div>&nbsp;</div>
<div>Zus&auml;tzlich: Hauptstra&szlig;e &uarr;<br>Ende</div>''';

      // Line breaks in the source are spaces, as in a browser; the empty
      // spacer divs become one empty line.
      expect(
        efaPlainText(html),
        'Linien 345, 355: '
        'Zwischen (H) Bochum, Lessing-Schule und (H) Sportplatz.\n'
        'Dauer: 08.06.26 bis 04.01.27\n'
        'Umbau\n'
        '\n'
        'Beginn: Montag\n'
        '\n'
        'Zusätzlich: Hauptstraße ↑\n'
        'Ende',
      );
    });

    test('keeps one empty line between paragraphs at most', () {
      expect(efaPlainText('Eins\n\n\n\nZwei\n\n'), 'Eins\n\nZwei');
    });

    test('decodes numeric entities and keeps unknown ones', () {
      expect(efaPlainText('&#252; &#xE4; &unknown;'), 'ü ä &unknown;');
    });

    test('list items become bullets', () {
      expect(efaPlainText('<ul><li>A</li><li>B</li></ul>'), '• A\n• B');
    });
  });
}
