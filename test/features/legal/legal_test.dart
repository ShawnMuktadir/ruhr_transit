import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/l10n/app_language.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/features/legal/presentation/legal_page.dart';
import 'package:ruhr_transit/features/legal/presentation/markdown_view.dart';

void main() {
  group('parseMarkdown', () {
    test('reads headings, paragraphs, bullets and callouts', () {
      final blocks = parseMarkdown('''
> **Draft** – check
> before publishing.

# Title

First line
second line.

## Section
- one
  continued
- two

Last.
''');

      expect(blocks.map((b) => (b.runtimeType, b.text)), [
        (MarkdownCallout, '**Draft** – check before publishing.'),
        (MarkdownHeading, 'Title'),
        (MarkdownParagraph, 'First line second line.'),
        (MarkdownHeading, 'Section'),
        (MarkdownBullet, 'one continued'),
        (MarkdownBullet, 'two'),
        (MarkdownParagraph, 'Last.'),
      ]);
      expect((blocks[1] as MarkdownHeading).level, 1);
      expect((blocks[3] as MarkdownHeading).level, 2);
    });

    test('bold parts are bold, the rest is not', () {
      final span = inlineSpans('no **ads** at all', null);
      final parts = span.children!.cast<TextSpan>();

      expect(parts.map((p) => p.text), ['no ', 'ads', ' at all']);
      expect(parts[1].style?.fontWeight, FontWeight.bold);
      expect(parts[0].style, isNull);
    });
  });

  group('legal texts', () {
    // Adding a language must not leave the legal pages without a text.
    test('exist for every language, marked as drafts', () {
      for (final document in LegalDocument.values) {
        for (final language in AppLanguages.all) {
          final file = File(document.assetFor(language));
          expect(file.existsSync(), isTrue, reason: file.path);
          final first = parseMarkdown(file.readAsStringSync()).first;
          expect(first, isA<MarkdownCallout>(), reason: file.path);
          expect(
            first.text,
            matches(RegExp('Entwurf|Draft')),
            reason: file.path,
          );
        }
      }
    });

    test('say only what the app does', () {
      for (final language in AppLanguages.all) {
        final privacy = File(
          LegalDocument.privacy.assetFor(language),
        ).readAsStringSync();
        // Values from the code: the nearby search radius and the number of
        // boards kept for offline use.
        expect(privacy, contains('1 km'));
        expect(privacy, contains('10'));
        expect(privacy, contains('openservice.vrr.de'));
      }
    });
  });

  group('LegalPage', () {
    Future<void> pumpPage(
      WidgetTester tester,
      LegalDocument document, {
      String locale = 'en',
      AssetBundle? bundle,
    }) async {
      final page = LegalPage(document);
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: bundle == null
              ? page
              : DefaultAssetBundle(bundle: bundle, child: page),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows the privacy policy in English with the draft note', (
      tester,
    ) async {
      await pumpPage(tester, LegalDocument.privacy);

      expect(find.text('Privacy policy'), findsWidgets);
      expect(find.textContaining('Draft – review before'), findsOneWidget);
      expect(find.textContaining('no user account'), findsOneWidget);
    });

    testWidgets('shows the terms in German', (tester) async {
      await pumpPage(tester, LegalDocument.terms, locale: 'de');

      expect(find.text('Nutzungsbedingungen'), findsWidgets);
      expect(find.textContaining('keine App des VRR'), findsOneWidget);
    });

    testWidgets('explains a loading error and retries', (tester) async {
      final bundle = _FlakyBundle();
      await pumpPage(tester, LegalDocument.privacy, bundle: bundle);
      expect(find.text('The text could not be loaded.'), findsOneWidget);

      bundle.fail = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.textContaining('# '), findsNothing);
      expect(find.text('Loaded'), findsOneWidget);
    });
  });
}

class _FlakyBundle extends CachingAssetBundle {
  bool fail = true;

  @override
  Future<ByteData> load(String key) => throw UnimplementedError();

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (fail) throw FlutterError('Unable to load asset: $key');
    return '# Loaded';
  }
}
