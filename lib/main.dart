import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:ruhr_transit/app.dart';
import 'package:ruhr_transit/core/di/injection.dart';
import 'package:ruhr_transit/core/l10n/app_language.dart';
import 'package:ruhr_transit/features/favourites/domain/favourites_repository.dart';
import 'package:ruhr_transit/features/language/domain/language_repository.dart';
import 'package:ruhr_transit/features/onboarding/domain/onboarding_repository.dart';
import 'package:ruhr_transit/features/recent_stops/domain/recent_stops_repository.dart';
import 'package:ruhr_transit/features/reminders/domain/reminder_repository.dart';
import 'package:ruhr_transit/features/settings/domain/theme_repository.dart';
import 'package:ruhr_transit/features/settings/presentation/theme_cubit.dart';
import 'package:ruhr_transit/features/widget_sync/domain/widget_sync.dart';

Future<void> main() async {
  // Plugins (shared_preferences) need the binding before runApp.
  WidgetsFlutterBinding.ensureInitialized();
  // Lets alarms run the reminder check while the app is closed.
  await AndroidAlarmManager.initialize();
  configureDependencies();
  // Loaded up front, so the start screen never flashes the empty state and
  // a change can never race the load. It is a single local read.
  final favourites = await getIt<FavouritesRepository>().load();
  // Also loaded up front, for the same reason as favourites.
  final recentStops = await getIt<RecentStopsRepository>().load();
  // Started from the home-screen widget or a reminder notification.
  final launchedStop =
      await getIt<WidgetSync>().launchedStop() ??
      await getIt<ReminderNotifier>().launchedStop();
  // Also read up front, so the first frame is already in the right language,
  // theme and screen.
  final language = AppLanguages.byCode(
    await getIt<LanguageRepository>().load(),
  );
  final onboarded = await getIt<OnboardingRepository>().isCompleted();
  final themeMode = ThemeCubit.parse(await getIt<ThemeRepository>().load());
  runApp(
    RuhrTransitApp(
      initialFavourites: favourites,
      initialRecentStops: recentStops,
      launchedStop: launchedStop,
      language: language,
      showOnboarding: !onboarded,
      themeMode: themeMode,
    ),
  );
}
