import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/features/departures/presentation/departures_page.dart';
import 'package:ruhr_transit/features/favourite_journeys/domain/favourite_journey.dart';
import 'package:ruhr_transit/features/home/presentation/favourites_tab.dart';
import 'package:ruhr_transit/features/nearby_stops/presentation/nearby_stops_page.dart';
import 'package:ruhr_transit/features/settings/presentation/settings_page.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/trip_form_cubit.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/trip_form_page.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/trip_results_page.dart';

enum HomeTab { plan, nearby, favourites, settings }

/// The main screen: a navigation bar with one navigator per tab.
///
/// An IndexedStack keeps every visited tab alive, so each keeps its own
/// back stack, scroll position and input. go_router's StatefulShellRoute
/// would do the same, but the app does not use go_router, and adding it
/// would mean rewriting all existing navigation for this one feature.
///
/// Tabs are built on first visit only, so "Stops near me" does not start
/// anything before it is opened.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => HomeShellState();
}

class HomeShellState extends State<HomeShell> {
  var _tab = HomeTab.plan;
  final _visited = {HomeTab.plan};
  final _navigators = {
    for (final tab in HomeTab.values) tab: GlobalKey<NavigatorState>(),
  };
  final _segment = ValueNotifier(FavouritesSegment.journeys);

  /// Owned here rather than by the planner page, so a saved journey can
  /// fill in the form.
  final _tripForm = TripFormCubit();

  @override
  void dispose() {
    _segment.dispose();
    unawaited(_tripForm.close());
    super.dispose();
  }

  void _select(HomeTab tab) {
    if (tab == _tab) {
      // Tapping the open tab again returns to its start.
      _navigators[tab]!.currentState?.popUntil((route) => route.isFirst);
      return;
    }
    // A text field in the hidden tab would otherwise keep the keyboard open.
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _tab = tab;
      _visited.add(tab);
    });
  }

  /// Runs [action] with [tab]'s navigator, once the tab is built.
  void _inTab(HomeTab tab, void Function(NavigatorState navigator) action) {
    _select(tab);
    void run() {
      final navigator = _navigators[tab]!.currentState;
      if (navigator == null || !mounted) return;
      navigator.popUntil((route) => route.isFirst);
      action(navigator);
    }

    if (_navigators[tab]!.currentState != null) {
      run();
    } else {
      // Built on its first visit, in the frame _select scheduled.
      WidgetsBinding.instance.addPostFrameCallback((_) => run());
    }
  }

  /// Opens [stop]'s board above the favourite stops, e.g. for a tap on the
  /// home-screen widget. Back returns to the stops.
  void openBoard(Stop stop) {
    _segment.value = FavouritesSegment.stops;
    _inTab(
      HomeTab.favourites,
      (navigator) => unawaited(
        navigator.push(
          MaterialPageRoute<void>(builder: (_) => DeparturesPage(stop: stop)),
        ),
      ),
    );
  }

  /// Fills the planner with [journey] and searches from now.
  void planJourney(FavouriteJourney journey) {
    _tripForm
      ..setFrom(journey.from)
      ..setTo(journey.to)
      ..leaveNow();
    final query = _tripForm.state.query;
    if (query == null) return;
    _inTab(
      HomeTab.plan,
      (navigator) => unawaited(
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => TripResultsPage(query: query),
          ),
        ),
      ),
    );
  }

  /// Whether Back stays in the app: something to pop in the open tab, or a
  /// tab other than the planner open. Only on the planner's start does the
  /// system get Back, which closes the app with its predictive animation.
  bool get _handlesBack =>
      _tab != HomeTab.plan ||
      (_navigators[_tab]!.currentState?.canPop() ?? false);

  /// Android Back: first within the tab, then back to the first tab.
  Future<void> _back() async {
    final navigator = _navigators[_tab]!.currentState;
    if (navigator != null && await navigator.maybePop()) return;
    if (_tab != HomeTab.plan) setState(() => _tab = HomeTab.plan);
  }

  /// The tab navigators report whether they can pop, and WidgetsApp passes
  /// that on to Android 14+, which then decides whether Back reaches the app
  /// at all. A tab at its start would report "no" and Back would close the
  /// app, although it should switch to the planner. So their reports stop
  /// here; the PopScope below reports for the whole shell instead.
  bool _onTabNavigation(NavigationNotification notification) {
    // Rebuild with the new answer, after the navigator finished updating.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
    return true;
  }

  Widget _root(HomeTab tab) => switch (tab) {
    HomeTab.plan => BlocProvider.value(
      value: _tripForm,
      child: const TripFormView(),
    ),
    HomeTab.nearby => const NearbyStopsPage(),
    HomeTab.favourites => FavouritesTab(
      segment: _segment,
      onOpenJourney: planJourney,
    ),
    HomeTab.settings => const SettingsPage(),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopScope(
      canPop: !_handlesBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_back());
      },
      child: Scaffold(
        body: NotificationListener<NavigationNotification>(
          onNotification: _onTabNavigation,
          child: IndexedStack(
            index: _tab.index,
            children: [
              for (final tab in HomeTab.values)
                if (_visited.contains(tab))
                  // Hidden tabs keep their state but stop animating.
                  TickerMode(
                    enabled: tab == _tab,
                    child: _TabNavigator(
                      navigatorKey: _navigators[tab]!,
                      root: _root(tab),
                    ),
                  )
                else
                  const SizedBox.shrink(),
            ],
          ),
        ),
        // Material grows the labels up to 1.3x; "Einstellungen" then no
        // longer fits a tab on a 360 dp phone and is cut off. 1.15x still
        // fits; the icons and screen reader labels are not affected.
        bottomNavigationBar: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.15,
          child: NavigationBar(
            selectedIndex: _tab.index,
            onDestinationSelected: (index) => _select(HomeTab.values[index]),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.directions_outlined),
                selectedIcon: const Icon(Icons.directions),
                label: l10n.navPlan,
              ),
              NavigationDestination(
                icon: const Icon(Icons.near_me_outlined),
                selectedIcon: const Icon(Icons.near_me),
                label: l10n.navNearby,
              ),
              NavigationDestination(
                icon: const Icon(Icons.star_outline),
                selectedIcon: const Icon(Icons.star),
                label: l10n.navFavourites,
              ),
              NavigationDestination(
                icon: const Icon(Icons.settings_outlined),
                selectedIcon: const Icon(Icons.settings),
                label: l10n.navSettings,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabNavigator extends StatelessWidget {
  const _TabNavigator({required this.navigatorKey, required this.root});

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget root;

  @override
  Widget build(BuildContext context) {
    // Each navigator needs its own hero controller; MaterialApp's belongs to
    // the root navigator.
    return HeroControllerScope.none(
      child: Navigator(
        key: navigatorKey,
        onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => root),
      ),
    );
  }
}
