import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/core/widgets/app_loader.dart';
import 'package:ruhr_transit/core/widgets/clock_time.dart';
import 'package:ruhr_transit/core/widgets/data_attribution.dart';
import 'package:ruhr_transit/features/favourite_journeys/presentation/favourite_journey_button.dart';
import 'package:ruhr_transit/features/profile/presentation/profile_cubit.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';
import 'package:ruhr_transit/features/stop_search/presentation/stop_search_page.dart';
import 'package:ruhr_transit/features/trip_planner/domain/current_location_finder.dart';
import 'package:ruhr_transit/features/trip_planner/domain/trip_query.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/greeting_header.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/stop_actions.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/trip_form_cubit.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/trip_results_page.dart';
import 'package:ruhr_transit/features/weather/presentation/weather_backdrop.dart';
import 'package:ruhr_transit/features/weather/presentation/weather_chip.dart';
import 'package:ruhr_transit/features/weather/presentation/weather_cubit.dart';

/// The planner. Its [TripFormCubit] comes from the home shell, which can
/// fill it in from a saved journey.
class TripFormView extends StatelessWidget {
  const TripFormView({
    this.pickStop = StopPicker.pick,
    this.now = DateTime.now,
    this.showWeather = false,
    this.here,
    super.key,
  });

  /// Finds the user's location as a start; without it, no location button.
  final CurrentLocationFinder? here;

  /// The weather chip and background; needs a [WeatherCubit] above.
  final bool showWeather;

  /// Opens the stop picker; tests replace it.
  final Future<Stop?> Function(BuildContext context, {required String title})
  pickStop;

  /// The clock the greeting is for.
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<TripFormCubit>();
    final look = showWeather
        ? WeatherLook.of(
            context.select((WeatherCubit weather) => weather.sky),
            Theme.of(context).brightness,
          )
        : null;
    return Scaffold(
      // The sky reaches up behind the bar and the status bar.
      extendBodyBehindAppBar: true,
      // The greeting below is the title; the bar keeps the bookmark.
      appBar: AppBar(
        // Clear over the sky, and the sky's colour when the page scrolls
        // under it, so its icons fit either way.
        backgroundColor: switch (look) {
          final look? => WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.scrolledUnder)
                ? look.top
                : look.top.withValues(alpha: 0),
          ),
          null => null,
        },
        foregroundColor: look?.foreground,
        scrolledUnderElevation: look == null ? null : 0,
        systemOverlayStyle: switch (look) {
          final look? =>
            look.isDark
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark,
          null => null,
        },
        actions: [
          IconButtonTheme(
            // Full strength on the sky, even before there is a journey to
            // save: the usual faded grey is hard to see there.
            data: switch (look) {
              final look? => IconButtonThemeData(
                style: IconButton.styleFrom(
                  foregroundColor: look.icon,
                  disabledForegroundColor: look.icon,
                ),
              ),
              null => IconButtonTheme.of(context),
            },
            child: BlocBuilder<TripFormCubit, TripFormState>(
              builder: (context, state) =>
                  FavouriteJourneyButton(from: state.from, to: state.to),
            ),
          ),
        ],
      ),
      body: BlocBuilder<TripFormCubit, TripFormState>(
        builder: (context, state) => ListView(
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            _Header(look: look, showWeather: showWeather, now: now),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    margin: EdgeInsets.zero,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              _StopField(
                                label: l10n.tripFrom,
                                placeholder: l10n.tripChooseFrom,
                                icon: Icons.trip_origin,
                                stop: state.from,
                                isHere:
                                    state.from != null &&
                                    state.from == state.here,
                                trailing: switch (here) {
                                  final here? => _HereButton(here),
                                  null => null,
                                },
                                onTap: () async {
                                  final stop = await pickStop(
                                    context,
                                    title: l10n.tripChooseFrom,
                                  );
                                  if (stop != null) cubit.setFrom(stop);
                                },
                              ),
                              const Divider(height: 1, indent: 56),
                              _StopField(
                                label: l10n.tripTo,
                                placeholder: l10n.tripChooseTo,
                                icon: Icons.place,
                                stop: state.to,
                                isHere:
                                    state.to != null && state.to == state.here,
                                onTap: () async {
                                  final stop = await pickStop(
                                    context,
                                    title: l10n.tripChooseTo,
                                  );
                                  if (stop != null) cubit.setTo(stop);
                                },
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.swap_vert),
                          tooltip: l10n.tripSwap,
                          onPressed: state.from == null && state.to == null
                              ? null
                              : cubit.swap,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _TimeChooser(state.time),
                  const SizedBox(height: 24),
                  if (state.isSameStop)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        l10n.tripSameStop,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  FilledButton.icon(
                    icon: const Icon(Icons.search),
                    label: Text(l10n.tripSearch),
                    onPressed: switch (state.query) {
                      final query? => () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => TripResultsPage(query: query),
                        ),
                      ),
                      null => null,
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const DataAttribution(),
    );
  }
}

/// The greeting and the weather, on the sky when there is weather to show.
class _Header extends StatelessWidget {
  const _Header({
    required this.look,
    required this.showWeather,
    required this.now,
  });

  final WeatherLook? look;
  final bool showWeather;
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) {
    final look = this.look;
    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 400),
            layoutBuilder: (current, previous) =>
                Stack(fit: StackFit.expand, children: [...previous, ?current]),
            child: look == null
                ? null
                : WeatherBackdrop(key: ValueKey(look), look: look),
          ),
        ),
        Padding(
          // Below the status bar and the app bar, and clear of the fade.
          padding: EdgeInsets.fromLTRB(
            16,
            MediaQuery.paddingOf(context).top,
            16,
            WeatherBackdrop.fadeHeight,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Its own stop for TalkBack, apart from the weather below.
              Semantics(
                container: true,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: BlocSelector<ProfileCubit, ProfileState, String?>(
                    selector: (state) => state.displayName,
                    builder: (context, name) => GreetingHeader(
                      displayName: name,
                      now: now,
                      color: look?.foreground,
                      secondaryColor: look?.secondary,
                    ),
                  ),
                ),
              ),
              if (showWeather) ...[
                const SizedBox(height: 20),
                WeatherChip(footnoteColor: look?.secondary),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _StopField extends StatelessWidget {
  const _StopField({
    required this.label,
    required this.placeholder,
    required this.icon,
    required this.stop,
    required this.onTap,
    this.isHere = false,
    this.trailing,
  });

  final String label;
  final String placeholder;
  final IconData icon;
  final Stop? stop;
  final VoidCallback onTap;

  /// [stop] is the user's location: "Von · Aktueller Standort".
  final bool isHere;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(
        isHere ? Icons.my_location : icon,
        color: isHere ? theme.colorScheme.primary : null,
      ),
      title: Text(
        isHere ? '$label · ${l10n.tripCurrentLocation}' : label,
        style: theme.textTheme.labelMedium,
      ),
      trailing: trailing,
      subtitle: Text(
        stop?.fullName ?? placeholder,
        // Two lines, so names stay readable at large font sizes.
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleMedium?.copyWith(
          color: stop == null ? theme.colorScheme.onSurfaceVariant : null,
        ),
      ),
      onTap: onTap,
    );
  }
}

enum _TimeKind { now, depart, arrive }

/// Now / depart / arrive, and the date and time for the latter two.
class _TimeChooser extends StatelessWidget {
  const _TimeChooser(this.time);

  final TripTime time;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<TripFormCubit>();
    final (kind, chosen) = switch (time) {
      LeaveNow() => (_TimeKind.now, null),
      DepartAt(:final time) => (_TimeKind.depart, time),
      ArriveBy(:final time) => (_TimeKind.arrive, time),
    };

    void setTime(DateTime value) => kind == _TimeKind.arrive
        ? cubit.arriveBy(value)
        : cubit.departAt(value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<_TimeKind>(
          segments: [
            ButtonSegment(value: _TimeKind.now, label: Text(l10n.tripNow)),
            ButtonSegment(
              value: _TimeKind.depart,
              label: Text(l10n.tripDepartAt),
            ),
            ButtonSegment(
              value: _TimeKind.arrive,
              label: Text(l10n.tripArriveBy),
            ),
          ],
          selected: {kind},
          onSelectionChanged: (selection) => switch (selection.single) {
            _TimeKind.now => cubit.leaveNow(),
            _TimeKind.depart => cubit.departAt(),
            _TimeKind.arrive => cubit.arriveBy(),
          },
        ),
        if (chosen != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    MaterialLocalizations.of(context).formatMediumDate(chosen),
                  ),
                  onPressed: () async {
                    final today = DateUtils.dateOnly(DateTime.now());
                    final date = await showDatePicker(
                      context: context,
                      initialDate: chosen.isBefore(today) ? today : chosen,
                      firstDate: today,
                      // Well within EFA's timetable period.
                      lastDate: today.add(const Duration(days: 30)),
                    );
                    if (date == null) return;
                    setTime(
                      DateTime(
                        date.year,
                        date.month,
                        date.day,
                        chosen.hour,
                        chosen.minute,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.schedule),
                  label: Text(formatClockTime(context, chosen.toUtc())),
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(chosen),
                    );
                    if (picked == null) return;
                    setTime(
                      DateTime(
                        chosen.year,
                        chosen.month,
                        chosen.day,
                        picked.hour,
                        picked.minute,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Puts the user's location into "Von": asks for the permission if needed
/// and explains in a snack bar when it cannot.
class _HereButton extends StatefulWidget {
  const _HereButton(this.finder);

  final CurrentLocationFinder finder;

  @override
  State<_HereButton> createState() => _HereButtonState();
}

class _HereButtonState extends State<_HereButton> {
  var _finding = false;

  Future<void> _find() async {
    setState(() => _finding = true);
    final result = await widget.finder.find();
    if (!mounted) return;
    setState(() => _finding = false);

    if (result case HereFound(:final stop)) {
      context.read<TripFormCubit>().setFromHere(stop);
      return;
    }
    showHereProblem(context, result, widget.finder);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_finding) {
      return Semantics(
        label: l10n.tripLocating,
        liveRegion: true,
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: AppLoader.small(),
        ),
      );
    }
    return IconButton(
      icon: const Icon(Icons.my_location),
      tooltip: l10n.tripUseLocation,
      onPressed: () => unawaited(_find()),
    );
  }
}
