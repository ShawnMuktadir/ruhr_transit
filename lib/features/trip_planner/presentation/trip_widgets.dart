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
    // A Wrap, so the delay moves under the time when space runs out, e.g.
    // at large font sizes.
    return Wrap(
      spacing: 4,
      children: [
        Text(formatClockTime(context, stop.plannedTime), style: base),
        if (delayMinutes != 0) ...[
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

/// `16:06 +8 → 16:28 +11`, wrapping onto a second line when it does not
/// fit, e.g. at large font sizes.
class JourneyTimes extends StatelessWidget {
  const JourneyTimes(this.journey, {super.key});

  final Journey journey;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        TripTimeText(journey.departure),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.arrow_forward, size: 16),
        ),
        TripTimeText(journey.arrival),
      ],
    );
  }
}

/// One sentence for screen readers, e.g. "Departs 16:06, arrives 16:28,
/// 8 min late, 30 min, 1 change, 378, S1", instead of the card's pieces.
String journeySummary(BuildContext context, Journey journey) {
  final l10n = AppLocalizations.of(context);

  String timeOf(TripStop stop) {
    final time = formatClockTime(context, stop.plannedTime);
    final delay = stop.delay?.inMinutes ?? 0;
    return switch (delay) {
      > 0 => '$time, ${l10n.departureLate(delay)}',
      < 0 => '$time, ${l10n.departureEarly(-delay)}',
      _ => time,
    };
  }

  final transfers = journey.transfers;
  final details = [
    formatTripDuration(l10n, journey.duration),
    if (transfers == 0) l10n.tripDirect else l10n.tripTransfers(transfers),
    for (final leg in journey.legs)
      switch (leg) {
        TransitLeg(:final line) => line,
        WalkLeg() => l10n.tripWalkLabel,
      },
    if (journey.notices case final notices when notices.isNotEmpty)
      l10n.tripNotices(notices.length),
    if (journey.hasWarning) l10n.noticeAffectsTrip,
    if (journey.platformChanges case final changes when changes.isNotEmpty)
      l10n.tripPlatformChanges(changes.length),
    if (journey.isTimetableOnly) l10n.tripTimetableOnly,
  ].join(', ');
  return l10n.tripSummary(
    timeOf(journey.departure),
    timeOf(journey.arrival),
    details,
  );
}

/// "Platform change" in the error colours when a ride boards or ends at
/// another platform than planned; nothing otherwise. Where it changed shows
/// in the trip's details, on the platform itself.
class PlatformChangeNote extends StatelessWidget {
  const PlatformChangeNote(this.journey, {super.key});

  final Journey journey;

  @override
  Widget build(BuildContext context) {
    final changes = journey.platformChanges.length;
    if (changes == 0) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final color = theme.colorScheme.error;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.swap_horiz, size: 16, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            AppLocalizations.of(context).tripPlatformChanges(changes),
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
