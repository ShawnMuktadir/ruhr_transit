import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ruhr_transit/app.dart';
import 'package:ruhr_transit/core/di/injection.dart';
import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/core/l10n/app_language.dart';
import 'package:ruhr_transit/features/departures/domain/departure_repository.dart';
import 'package:ruhr_transit/features/departures/presentation/departures_page.dart';
import 'package:ruhr_transit/features/favourite_journeys/domain/favourite_journeys_repository.dart';
import 'package:ruhr_transit/features/favourites/domain/favourites_repository.dart';
import 'package:ruhr_transit/features/language/domain/language_repository.dart';
import 'package:ruhr_transit/features/onboarding/domain/onboarding_repository.dart';
import 'package:ruhr_transit/features/profile/domain/auth_repository.dart';
import 'package:ruhr_transit/features/profile/domain/profile_repository.dart';
import 'package:ruhr_transit/features/recent_stops/domain/recent_stops_repository.dart';
import 'package:ruhr_transit/features/settings/domain/theme_repository.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop_repository.dart';
import 'package:ruhr_transit/features/widget_sync/domain/widget_sync.dart';

import 'helpers/fake_departure_repository.dart';
import 'helpers/fake_favourite_journeys_repository.dart';
import 'helpers/fake_favourites_repository.dart';
import 'helpers/fake_recent_stops_repository.dart';
import 'helpers/fake_settings.dart';
import 'helpers/fake_stop_repository.dart';
import 'helpers/fake_widget_sync.dart';

void main() {
  late FakeWidgetSync widgetSync;
  late FakeLanguageRepository language;
  late FakeOnboardingRepository onboarding;

  // The real app resolves the repositories through get_it; fakes keep the
  // smoke tests off the network and the platform.
  setUp(() {
    widgetSync = FakeWidgetSync();
    language = FakeLanguageRepository();
    onboarding = FakeOnboardingRepository();
    getIt
      ..registerFactory<StopRepository>(FakeStopRepository.new)
      ..registerFactory<DepartureRepository>(
        () => FakeDepartureRepository()..autoReply = const Ok([]),
      )
      ..registerSingleton<FavouritesRepository>(FakeFavouritesRepository())
      ..registerSingleton<WidgetSync>(widgetSync)
      ..registerSingleton<LanguageRepository>(language)
      ..registerSingleton<OnboardingRepository>(onboarding)
      ..registerSingleton<FavouriteJourneysRepository>(
        FakeFavouriteJourneysRepository(),
      )
      ..registerSingleton<ThemeRepository>(FakeThemeRepository())
      ..registerSingleton<RecentStopsRepository>(FakeRecentStopsRepository())
      ..registerSingleton<ProfileRepository>(FakeProfileRepository())
      ..registerSingleton<AuthRepository>(FakeAuthRepository());
    PackageInfo.setMockInitialValues(
      appName: 'RuhrTransit',
      packageName: 'de.muktadir.ruhrtransit',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });
  tearDown(getIt.reset);

  group('RuhrTransitApp localization', () {
    testWidgets('falls back to German for an unsupported device locale', (
      tester,
    ) async {
      tester.platformDispatcher.localesTestValue = const [Locale('fr', 'FR')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);

      await tester.pumpWidget(const RuhrTransitApp());
      await tester.pumpAndSettle();

      expect(find.text('Verbindung suchen'), findsOneWidget);
      expect(find.text('Einstellungen'), findsOneWidget);
      expect(find.textContaining('Alle Angaben ohne Gewähr'), findsOneWidget);
    });

    testWidgets('uses English on an English device', (tester) async {
      tester.platformDispatcher.localesTestValue = const [Locale('en', 'GB')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);

      await tester.pumpWidget(const RuhrTransitApp());
      await tester.pumpAndSettle();

      expect(find.text('Plan a trip'), findsOneWidget);
      expect(
        find.textContaining('All information without guarantee'),
        findsOneWidget,
      );
    });
  });

  group('RuhrTransitApp theme', () {
    testWidgets('a saved theme applies from the first frame', (tester) async {
      await tester.pumpWidget(const RuhrTransitApp(themeMode: ThemeMode.dark));

      final context = tester.element(find.byType(Scaffold).first);
      expect(Theme.of(context).brightness, Brightness.dark);
    });

    testWidgets('uses the dark theme when the system is dark', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await tester.pumpWidget(const RuhrTransitApp());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(Scaffold).first);
      expect(Theme.of(context).brightness, Brightness.dark);
      expect(Theme.of(context).useMaterial3, isTrue);
    });
  });

  group('RuhrTransitApp home-screen widget', () {
    testWidgets('a widget launch opens the board above the stops', (
      tester,
    ) async {
      await tester.pumpWidget(const RuhrTransitApp(launchedStop: bochumHbf));
      await tester.pumpAndSettle();

      expect(find.byType(DeparturesPage), findsOneWidget);
      expect(find.text('Bochum, Hbf'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(DeparturesPage), findsNothing);
      // The Favourites tab, on its stops segment with the search.
      expect(find.text('Favourites'), findsWidgets);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('a widget tap while running opens the board', (tester) async {
      await tester.pumpWidget(const RuhrTransitApp());
      await tester.pumpAndSettle();
      expect(find.byType(DeparturesPage), findsNothing);

      widgetSync.taps.add(dortmundHbf);
      await tester.pumpAndSettle();

      expect(find.text('Dortmund, Hbf'), findsOneWidget);
    });

    testWidgets('repeated widget taps do not stack boards', (tester) async {
      await tester.pumpWidget(const RuhrTransitApp(launchedStop: bochumHbf));
      await tester.pumpAndSettle();

      widgetSync.taps
        ..add(bochumHbf)
        ..add(bochumHbf);
      await tester.pumpAndSettle();
      expect(find.byType(DeparturesPage), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
    });
  });

  group('RuhrTransitApp first launch', () {
    void deviceLocale(WidgetTester tester, Locale locale) {
      tester.platformDispatcher.localesTestValue = [locale];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    }

    AppLanguage? selectedLanguage(WidgetTester tester) => tester
        .widget<RadioGroup<AppLanguage>>(find.byType(RadioGroup<AppLanguage>))
        .groupValue;

    testWidgets('welcome, then the device language, switched live', (
      tester,
    ) async {
      deviceLocale(tester, const Locale('en', 'GB'));
      await tester.pumpWidget(const RuhrTransitApp(showOnboarding: true));
      await tester.pumpAndSettle();

      expect(find.text('RuhrTransit'), findsOneWidget);
      expect(find.textContaining('Live departures'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Choose a language'), findsOneWidget);
      expect(selectedLanguage(tester)?.code, 'en');

      // Applies at once, without a restart.
      await tester.tap(find.text('Deutsch'));
      await tester.pumpAndSettle();
      expect(find.text('Sprache wählen'), findsOneWidget);
      expect(language.saved, 'de');

      await tester.tap(find.text("Los geht's"));
      await tester.pumpAndSettle();
      expect(find.text('Verbindung suchen'), findsOneWidget);
      expect(onboarding.completed, isTrue);
    });

    testWidgets('an unsupported device language preselects German and '
        'saves it', (tester) async {
      deviceLocale(tester, const Locale('fr', 'FR'));
      await tester.pumpWidget(const RuhrTransitApp(showOnboarding: true));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Weiter'));
      await tester.pumpAndSettle();

      expect(selectedLanguage(tester)?.code, 'de');
      await tester.tap(find.text("Los geht's"));
      await tester.pumpAndSettle();

      // Saved, so a later change of the device language does not switch it.
      expect(language.saved, 'de');
      expect(find.text('Verbindung suchen'), findsOneWidget);
    });

    testWidgets('Back on the language step returns to the welcome', (
      tester,
    ) async {
      deviceLocale(tester, const Locale('en'));
      await tester.pumpWidget(const RuhrTransitApp(showOnboarding: true));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Android's Back button.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Continue'), findsOneWidget);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Continue'), findsOneWidget);
      expect(onboarding.completed, isFalse);
    });

    testWidgets('later launches go straight to the app in the saved '
        'language', (tester) async {
      deviceLocale(tester, const Locale('de'));
      await tester.pumpWidget(
        RuhrTransitApp(language: AppLanguages.byCode('en')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Plan a trip'), findsOneWidget);
    });

    testWidgets('a widget launch before onboarding only opens the app', (
      tester,
    ) async {
      await tester.pumpWidget(
        const RuhrTransitApp(showOnboarding: true, launchedStop: bochumHbf),
      );
      await tester.pumpAndSettle();
      widgetSync.taps.add(bochumHbf);
      await tester.pumpAndSettle();

      expect(find.byType(DeparturesPage), findsNothing);
    });

    testWidgets('a language set in Android settings applies while running', (
      tester,
    ) async {
      deviceLocale(tester, const Locale('de'));
      await tester.pumpWidget(
        RuhrTransitApp(language: AppLanguages.byCode('de')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Verbindung suchen'), findsOneWidget);

      // Android reports the new per-app language and a locale change.
      language.saved = 'en';
      tester.platformDispatcher.localesTestValue = const [Locale('en')];
      await tester.pumpAndSettle();

      expect(find.text('Plan a trip'), findsOneWidget);
    });
  });
}
