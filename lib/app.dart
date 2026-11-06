import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ruhr_transit/core/connectivity/connectivity.dart';
import 'package:ruhr_transit/core/connectivity/offline_banner.dart';
import 'package:ruhr_transit/core/di/injection.dart';
import 'package:ruhr_transit/core/l10n/app_language.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/core/theme/app_theme.dart';
import 'package:ruhr_transit/features/favourite_journeys/domain/favourite_journeys_repository.dart';
import 'package:ruhr_transit/features/favourite_journeys/presentation/favourite_journeys_cubit.dart';
import 'package:ruhr_transit/features/favourites/domain/favourites_repository.dart';
import 'package:ruhr_transit/features/favourites/presentation/favourites_cubit.dart';
import 'package:ruhr_transit/features/home/presentation/home_shell.dart';
import 'package:ruhr_transit/features/language/domain/language_repository.dart';
import 'package:ruhr_transit/features/language/presentation/locale_cubit.dart';
import 'package:ruhr_transit/features/nearby_stops/domain/location_source.dart';
import 'package:ruhr_transit/features/onboarding/domain/onboarding_repository.dart';
import 'package:ruhr_transit/features/onboarding/presentation/onboarding_cubit.dart';
import 'package:ruhr_transit/features/onboarding/presentation/onboarding_page.dart';
import 'package:ruhr_transit/features/profile/domain/auth_repository.dart';
import 'package:ruhr_transit/features/profile/domain/profile_repository.dart';
import 'package:ruhr_transit/features/profile/presentation/profile_cubit.dart';
import 'package:ruhr_transit/features/recent_stops/domain/recent_stops_repository.dart';
import 'package:ruhr_transit/features/recent_stops/presentation/recent_stops_cubit.dart';
import 'package:ruhr_transit/features/reminders/domain/reminder.dart';
import 'package:ruhr_transit/features/reminders/domain/reminder_repository.dart';
import 'package:ruhr_transit/features/reminders/presentation/reminders_cubit.dart';
import 'package:ruhr_transit/features/settings/domain/theme_repository.dart';
import 'package:ruhr_transit/features/settings/presentation/theme_cubit.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';
import 'package:ruhr_transit/features/widget_sync/domain/widget_sync.dart';

class RuhrTransitApp extends StatefulWidget {
  const RuhrTransitApp({
    this.initialFavourites = const [],
    this.initialRecentStops = const [],
    this.launchedStop,
    this.launchedReminder,
    this.language,
    this.showOnboarding = false,
    this.themeMode = ThemeMode.system,
    super.key,
  });

  /// What the favourites repository had stored when the app started.
  final List<Stop> initialFavourites;

  /// What the recent stops repository had stored when the app started.
  final List<Stop> initialRecentStops;

  /// The stop whose home-screen widget started the app. Its board opens
  /// above the favourite stops, so Back leads there.
  final Stop? launchedStop;

  /// What the notification that started the app opens, if one did.
  final ReminderOpening? launchedReminder;

  /// The chosen language, or null to follow the device.
  final AppLanguage? language;

  /// The chosen light/dark mode.
  final ThemeMode themeMode;

  /// True until the first-launch flow was completed once.
  final bool showOnboarding;

  @override
  State<RuhrTransitApp> createState() => _RuhrTransitAppState();
}

class _RuhrTransitAppState extends State<RuhrTransitApp>
    with WidgetsBindingObserver {
  /// Opens boards from widget taps, which come from outside the widget tree.
  final _shellKey = GlobalKey<HomeShellState>();
  late final StreamSubscription<Stop> _widgetTaps;
  late final StreamSubscription<ReminderOpening> _reminderTaps;

  // Created here rather than in BlocProviders, because the app itself
  // reacts to them (locale changes, widget taps before onboarding).
  late final _favourites = FavouritesCubit(
    getIt<FavouritesRepository>(),
    initial: widget.initialFavourites,
  );
  late final _locale = LocaleCubit(
    getIt<LanguageRepository>(),
    initial: widget.language,
  );
  late final _recentStops = RecentStopsCubit(
    getIt<RecentStopsRepository>(),
    initial: widget.initialRecentStops,
  );
  late final _favouriteJourneys = FavouriteJourneysCubit(
    getIt<FavouriteJourneysRepository>(),
  );
  late final _theme = ThemeCubit(
    getIt<ThemeRepository>(),
    initial: widget.themeMode,
  );
  late final _profile = ProfileCubit(
    getIt<ProfileRepository>(),
    getIt<AuthRepository>(),
  );
  late final _connectivity = ConnectivityCubit(getIt<ConnectivitySource>());
  late final _reminders = RemindersCubit(
    getIt<ReminderRepository>(),
    getIt<ReminderAlarms>(),
    getIt<ReminderNotifier>(),
    openAppSettings: getIt<LocationSource>().openAppSettings,
  );
  late final _onboarding = OnboardingCubit(
    getIt<OnboardingRepository>(),
    completed: !widget.showOnboarding,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _widgetTaps = getIt<WidgetSync>().openedStops.listen(_openBoard);
    _reminderTaps = getIt<ReminderNotifier>().opened.listen(_openReminder);
    if (widget.launchedReminder case final opening?) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openReminder(opening),
      );
    }
    if (widget.launchedStop case final stop?) {
      // The navigator exists only after the first frame.
      WidgetsBinding.instance.addPostFrameCallback((_) => _openBoard(stop));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_widgetTaps.cancel());
    unawaited(_reminderTaps.cancel());
    unawaited(_favourites.close());
    unawaited(_favouriteJourneys.close());
    unawaited(_recentStops.close());
    unawaited(_locale.close());
    unawaited(_onboarding.close());
    unawaited(_theme.close());
    unawaited(_profile.close());
    unawaited(_connectivity.close());
    unawaited(_reminders.close());
    super.dispose();
  }

  /// An alarm may have changed the reminders while the app was away.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_reminders.load());
  }

  /// The language may have been changed in Android's per-app settings.
  @override
  void didChangeLocales(List<Locale>? locales) => unawaited(_locale.refresh());

  /// Shows [stop]'s board directly above the favourite stops, so repeated
  /// widget taps do not stack boards and Back always leads to the stops.
  /// Before the first-launch flow is done, the widget only opens the app.
  void _openReminder(ReminderOpening opening) {
    if (_onboarding.state) {
      unawaited(_shellKey.currentState?.openReminder(opening));
    }
  }

  void _openBoard(Stop stop) {
    if (_onboarding.state) _shellKey.currentState?.openBoard(stop);
  }

  @override
  Widget build(BuildContext context) {
    // Above MaterialApp, so every route (search, departure boards) shares
    // the same favourites.
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _favourites),
        BlocProvider.value(value: _favouriteJourneys),
        BlocProvider.value(value: _recentStops),
        BlocProvider.value(value: _locale),
        BlocProvider.value(value: _onboarding),
        BlocProvider.value(value: _theme),
        BlocProvider.value(value: _profile),
        BlocProvider.value(value: _connectivity),
        BlocProvider.value(value: _reminders),
      ],
      child: Builder(
        builder: (context) => MaterialApp(
          locale: context.watch<LocaleCubit>().state?.locale,
          themeMode: context.watch<ThemeCubit>().state,
          onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          // German is listed first, so it is the fallback for any device locale
          // we don't support. English devices get English.
          supportedLocales: AppLocalizations.supportedLocales,
          debugShowCheckedModeBanner: false,
          // Above every page and dialog route.
          builder: (context, child) => OfflineBanner(child: child!),
          home: BlocBuilder<OnboardingCubit, bool>(
            builder: (context, completed) =>
                completed ? HomeShell(key: _shellKey) : const OnboardingPage(),
          ),
        ),
      ),
    );
  }
}
