import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/l10n/app_language.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';

void main() {
  group('AppLanguages', () {
    test('finds a language by code or tag', () {
      expect(AppLanguages.byCode('en')?.nativeName, 'English');
      expect(AppLanguages.byCode('de-DE')?.nativeName, 'Deutsch');
      expect(AppLanguages.byCode('EN_gb')?.code, 'en');
      expect(AppLanguages.byCode('fr'), isNull);
      expect(AppLanguages.byCode(null), isNull);
    });

    test('takes the first supported device language', () {
      expect(AppLanguages.forDevice(const [Locale('en', 'GB')]).code, 'en');
      expect(
        AppLanguages.forDevice(const [Locale('fr'), Locale('en')]).code,
        'en',
      );
    });

    test('falls back to German', () {
      expect(AppLanguages.forDevice(const [Locale('fr', 'FR')]).code, 'de');
      expect(AppLanguages.forDevice(const []).code, 'de');
    });

    // Adding a language takes three steps; this catches a missed one.
    test('matches the ARB files and Android locales_config.xml', () {
      final codes = [for (final language in AppLanguages.all) language.code];

      expect([
        for (final locale in AppLocalizations.supportedLocales)
          locale.languageCode,
      ], unorderedEquals(codes));

      final arbCodes = Directory('lib/core/l10n/arb')
          .listSync()
          .map((file) => RegExp(r'app_(\w+)\.arb$').firstMatch(file.path))
          .nonNulls
          .map((match) => match.group(1));
      expect(arbCodes, unorderedEquals(codes));

      final localesConfig = File(
        'android/app/src/main/res/xml/locales_config.xml',
      ).readAsStringSync();
      expect(
        RegExp(
          r'<locale android:name="(\w+)"',
        ).allMatches(localesConfig).map((match) => match.group(1)),
        unorderedEquals(codes),
      );
    });
  });
}
