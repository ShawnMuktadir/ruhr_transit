import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/build_legal_site.dart';

void main() {
  // The website and the app must say the same. After changing a text in
  // assets/legal/, run: dart run tool/build_legal_site.dart
  test('docs/ is built from the current legal texts', () {
    final site = buildSite(
      (asset) => File('assets/legal/$asset').readAsStringSync(),
    );
    for (final MapEntry(:key, :value) in site.entries) {
      final file = File('docs/$key');
      expect(file.existsSync(), isTrue, reason: key);
      expect(
        file.readAsStringSync().replaceAll('\r\n', '\n'),
        value,
        reason: '$key is out of date: run dart run tool/build_legal_site.dart',
      );
    }
  });

  test('the pages are plain: no scripts, no external files', () {
    for (final file in Directory('docs').listSync().whereType<File>()) {
      final text = file.readAsStringSync();
      expect(text, isNot(contains('<script')), reason: file.path);
      expect(
        RegExp(
          r'(src|href)="https?://(?!www\.bkg\.bund\.de|brightsky\.dev|'
          r'policies\.google\.com)',
        ).hasMatch(text),
        isFalse,
        reason: file.path,
      );
      expect(text, isNot(contains('–')), reason: file.path);
      expect(text, isNot(contains('—')), reason: file.path);
    }
  });

  test('no page has a draft note, every page links the other language', () {
    for (final page in pages) {
      final html = File('docs/${page.file}').readAsStringSync();
      expect(html, isNot(contains('class="draft"')), reason: page.file);
      expect(html, isNot(matches(RegExp('Draft|Entwurf'))), reason: page.file);
      expect(html, contains('href="${page.counterpart}"'), reason: page.file);
    }
  });
}
