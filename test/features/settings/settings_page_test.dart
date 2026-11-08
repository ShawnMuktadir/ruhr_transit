import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/core/platform/system_settings.dart';
import 'package:ruhr_transit/features/language/presentation/locale_cubit.dart';
import 'package:ruhr_transit/features/legal/presentation/legal_page.dart';
import 'package:ruhr_transit/features/profile/domain/auth_repository.dart';
import 'package:ruhr_transit/features/profile/presentation/profile_cubit.dart';
import 'package:ruhr_transit/features/profile/presentation/profile_page.dart';
import 'package:ruhr_transit/features/settings/presentation/settings_page.dart';
import 'package:ruhr_transit/features/settings/presentation/theme_cubit.dart';

import '../../helpers/fake_settings.dart';

void main() {
  late FakeThemeRepository theme;
  late FakeLanguageRepository language;
  late FakeProfileRepository profile;
  late FakeAuthRepository auth;

  setUp(() {
    theme = FakeThemeRepository();
    language = FakeLanguageRepository();
    profile = FakeProfileRepository();
    auth = FakeAuthRepository();
  });

  /// Like the app: the cubits above MaterialApp, which takes its theme and
  /// language from them.
  Future<void> pumpSettings(
    WidgetTester tester, {
    Future<PackageInfo> Function() packageInfo = fakePackageInfo,
    Future<void> Function()? openAccessibility,
  }) async {
    // Tall enough for the whole page, so every section is built.
    tester.view
      ..physicalSize = const Size(1080, 6000)
      ..devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => ThemeCubit(theme)),
          BlocProvider(create: (_) => LocaleCubit(language)),
          BlocProvider(create: (_) => ProfileCubit(profile, auth)),
        ],
        child: Builder(
          builder: (context) => MaterialApp(
            locale:
                context.watch<LocaleCubit>().state?.locale ??
                const Locale('en'),
            themeMode: context.watch<ThemeCubit>().state,
            theme: ThemeData.light(),
            darkTheme: ThemeData.dark(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SettingsPage(
              packageInfo: packageInfo,
              openAccessibility: openAccessibility ?? () async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Brightness brightness(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(SettingsPage))).brightness;

  group('accessibility', () {
    testWidgets('says what the app follows, TalkBack included', (tester) async {
      await pumpSettings(tester);
      expect(find.text('Accessibility'), findsOneWidget);
      expect(find.text('Larger text'), findsOneWidget);
      expect(find.text('Remove animations'), findsOneWidget);
      expect(find.text('TalkBack'), findsOneWidget);
      expect(find.textContaining('screen reader'), findsOneWidget);
      expect(find.textContaining('cannot do this itself'), findsOneWidget);
    });

    testWidgets("the button opens the phone's accessibility settings", (
      tester,
    ) async {
      var opened = 0;
      await pumpSettings(tester, openAccessibility: () async => opened++);
      await tester.tap(find.text('Open accessibility settings'));
      expect(opened, 1);
    });

    testWidgets('asks Android for its accessibility page', (tester) async {
      final calls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        systemSettingsChannel,
        (call) async => calls.add(call.method),
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          systemSettingsChannel,
          null,
        ),
      );
      await openAccessibilitySettings();
      expect(calls, ['accessibility']);
    });

    testWidgets('a refusal from Android is not an error', (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        systemSettingsChannel,
        (call) async => throw PlatformException(code: 'no-settings'),
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          systemSettingsChannel,
          null,
        ),
      );
      await openAccessibilitySettings();
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('the theme applies at once and is saved', (tester) async {
    await pumpSettings(tester);
    expect(brightness(tester), Brightness.light);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(brightness(tester), Brightness.dark);
    expect(theme.saved, 'dark');
  });

  testWidgets('the language applies at once and is saved', (tester) async {
    await pumpSettings(tester);

    await tester.tap(find.text('Deutsch'));
    await tester.pumpAndSettle();

    expect(find.text('Darstellung'), findsOneWidget);
    expect(language.saved, 'de');
  });

  testWidgets('shows the profile name, or that there is none', (tester) async {
    await pumpSettings(tester);
    expect(find.text('No name set'), findsOneWidget);

    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
    expect(find.byType(ProfilePage), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Kim');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsOneWidget);
    expect(profile.name, 'Kim');

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Kim'), findsOneWidget);
  });

  testWidgets('a failed save says so', (tester) async {
    profile.saveError = Exception('disk full');
    await pumpSettings(tester);
    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Kim');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('The name could not be saved.'), findsOneWidget);
  });

  testWidgets('no log out without an account', (tester) async {
    await pumpSettings(tester);

    expect(find.text('Log out'), findsNothing);
    expect(find.textContaining('Account'), findsNothing);

    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
    expect(find.text('Log out'), findsNothing);
    expect(find.textContaining('no user accounts yet'), findsOneWidget);
  });

  testWidgets('once signed in, log out appears and works', (tester) async {
    auth = FakeAuthRepository(
      const SignedIn(AuthUser(id: '1', displayName: 'kim@example.com')),
    );
    await pumpSettings(tester);

    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    expect(auth.signOutCalls, 1);
    expect(find.text('Log out'), findsNothing);
  });

  testWidgets('the signed-in profile shows the user and log out', (
    tester,
  ) async {
    auth = FakeAuthRepository(
      const SignedIn(AuthUser(id: '1', displayName: 'kim@example.com')),
    );
    await pumpSettings(tester);
    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();

    expect(find.text('Signed in as kim@example.com'), findsOneWidget);
    expect(find.text('Log out'), findsOneWidget);
  });

  testWidgets('opens the privacy policy and the terms', (tester) async {
    await pumpSettings(tester);

    await tester.ensureVisible(find.text('Privacy policy'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Privacy policy'));
    await tester.pumpAndSettle();
    expect(find.byType(LegalPage), findsOneWidget);
    expect(find.textContaining('Draft – review before'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Terms and conditions'));
    await tester.pumpAndSettle();
    expect(find.textContaining('not an app of VRR'), findsOneWidget);
  });

  testWidgets('about shows the version, attribution and licences', (
    tester,
  ) async {
    await pumpSettings(tester);
    await tester.ensureVisible(find.text('Open source licences'));
    await tester.pumpAndSettle();

    expect(find.text('Version 1.0.0 (1)'), findsOneWidget);
    expect(find.textContaining('Verkehrsverbund Rhein-Ruhr'), findsOneWidget);

    await tester.tap(find.text('Open source licences'));
    await tester.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
  });

  testWidgets('an unreadable version says so', (tester) async {
    await pumpSettings(
      tester,
      packageInfo: () async => throw Exception('no platform'),
    );
    await tester.ensureVisible(find.text('Open source licences'));
    await tester.pumpAndSettle();

    expect(find.text('Version unavailable'), findsOneWidget);
  });
}
