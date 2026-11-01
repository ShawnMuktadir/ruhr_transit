import 'package:flutter/material.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/core/widgets/clock_time.dart';
import 'package:ruhr_transit/core/widgets/line_badge.dart';
import 'package:ruhr_transit/features/trip_planner/domain/journey.dart';

/// `25 min` or `1 h 5 min`.
String formatTripDuration(AppLocalizations l10n, Duration duration) {
  final minutes = duration.inMinutes;
  return minutes < 60
      ? l10n.tripMinutes(minutes)
      : l10n.tripHoursMinutes(minutes ~/ 60, minutes % 60);
}

/// Planned time with the delay next to it (`17:14 +3`), like the departure
/// board: the planned time is what timetables and station boards show.
class TripTimeText extends StatelessWidget {
  const TripTimeText(this.stop, {this.style, super.key});

  final TripStop stop;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final base = style ?? theme.textTheme.titleMedium;
    final delayMinutes = stop.delay?.inMinutes ?? 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(formatClockTime(context, stop.plannedTime), style: base),
        if (delayMinutes != 0) ...[
          const SizedBox(width: 4),
          Text(
            delayMinutes > 0 ? '+$delayMinutes' : '$delayMinutes',
            semanticsLabel: delayMinutes > 0
                ? l10n.departureLate(delayMinutes)
                : l10n.departureEarly(-delayMinutes),
            style: base?.copyWith(
              color: delayMinutes > 0 ? theme.colorScheme.error : null,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ],
    );
  }
}

/// The rides of a journey as small badges, with a walking icon for walks.
class JourneyLines extends StatelessWidget {
  const JourneyLines(this.journey, {super.key});

  final Journey journey;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final (index, leg) in journey.legs.indexed) ...[
          if (index > 0) Icon(Icons.chevron_right, size: 16, color: color),
          switch (leg) {
            TransitLeg(:final line, :final mode) => LineBadge(
              line,
              mode: mode,
              minWidth: 0,
            ),
            WalkLeg() => Icon(Icons.directions_walk, size: 20, color: color),
          },
        ],
      ],
    );
  }
}

/// The day of [journey], e.g. `Mon, Nov 2`, when it is not today: times
/// alone would look like today's.
class JourneyDate extends StatelessWidget {
  const JourneyDate(this.journey, {super.key});

  final Journey journey;

  @override
  Widget build(BuildContext context) {
    final day = DateUtils.dateOnly(journey.departure.time.toLocal());
    if (DateUtils.isSameDay(day, DateTime.now())) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        MaterialLocalizations.of(context).formatMediumDate(day),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
