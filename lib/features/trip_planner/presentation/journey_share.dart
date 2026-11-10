import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/core/platform/share.dart';
import 'package:ruhr_transit/core/widgets/clock_time.dart';
import 'package:ruhr_transit/core/widgets/platform_chip.dart';
import 'package:ruhr_transit/core/widgets/show_message.dart';
import 'package:ruhr_transit/core/widgets/transport_mode_icon.dart';
import 'package:ruhr_transit/features/trip_planner/domain/journey.dart';
import 'package:ruhr_transit/features/trip_planner/domain/trip_query.dart';
import 'package:ruhr_transit/features/trip_planner/domain/vrr_trip_link.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/trip_widgets.dart';

/// A trip as text for a messenger or mail, in the app's language and clock
/// format, e.g.:
///
/// ```text
/// Bochum, Hbf → Essen, Hauptbahnhof
/// Tue, Nov 11, 2026 · 1:17 PM → 1:35 PM · 18 min · Direct
///
/// 1:17 PM  S-Bahn S1 → Düsseldorf Hbf, Bochum Hbf, Platform 4
/// 1:35 PM  Arrive at Essen Hbf
///
/// Live in VRR's journey planner:
/// https://efa.vrr.de/vrr/XSLT_TRIP_REQUEST2?…
///
/// Shared from RuhrTransit
/// ```
///
/// Times are the timetable's, with the delay next to them, like on screen.
/// The link needs the searched stops, so there is none without [query].
String journeyShareText(
  BuildContext context,
  Journey journey, {
  TripQuery? query,
}) {
  final l10n = AppLocalizations.of(context);

  String clock(TripStop stop) {
    final time = formatClockTime(context, stop.plannedTime);
    final delay = stop.delay?.inMinutes ?? 0;
    return switch (delay) {
      > 0 => '$time (${l10n.departureLate(delay)})',
      < 0 => '$time (${l10n.departureEarly(-delay)})',
      _ => time,
    };
  }

  final transfers = journey.transfers;
  final day = DateUtils.dateOnly(journey.departure.time.toLocal());
  return [
    '${query?.from.fullName ?? journey.departure.name} → '
        '${query?.to.fullName ?? journey.arrival.name}',
    [
      MaterialLocalizations.of(context).formatMediumDate(day),
      '${clock(journey.departure)} → ${clock(journey.arrival)}',
      formatTripDuration(l10n, journey.duration),
      if (transfers == 0) l10n.tripDirect else l10n.tripTransfers(transfers),
    ].join(' · '),
    '',
    for (final leg in journey.legs)
      switch (leg) {
        TransitLeg(:final mode, :final line, :final direction, :final origin) =>
          [
            '${clock(origin)}  '
                '${mode == null ? '' : '${transportModeLabel(l10n, mode)} '}'
                '$line → $direction',
            origin.name,
            ?platformLabel(l10n, origin.platform, mode: mode),
          ].join(', '),
        WalkLeg(:final origin, :final destination, :final duration) =>
          '${clock(origin)}  ${l10n.tripWalk(duration.inMinutes)} → '
              '${destination.name}',
      },
    '${clock(journey.arrival)}  ${l10n.shareArrive(journey.arrival.name)}',
    if (query != null) ...[
      '',
      l10n.shareLink,
      vrrTripLink(
        from: query.from,
        to: query.to,
        departure: journey.departure.plannedTime,
        languageCode: Localizations.localeOf(context).languageCode,
      ).toString(),
    ],
    '',
    l10n.shareFooter,
  ].join('\n');
}

/// "Copy" and "Share", for a trip in the results (long-press) and in its
/// details (share button).
abstract final class JourneyShareSheet {
  static Future<void> show(
    BuildContext context,
    Journey journey, {
    TripQuery? query,
  }) {
    final l10n = AppLocalizations.of(context);
    final text = journeyShareText(context, journey, query: query);
    final subject =
        '${query?.from.fullName ?? journey.departure.name} → '
        '${query?.to.fullName ?? journey.arrival.name}';
    final messenger = ScaffoldMessenger.of(context);
    return showModalBottomSheet<void>(
      context: context,
      // Over the whole screen, tab bar included, not just the tab.
      useRootNavigator: true,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Semantics(
                header: true,
                child: Text(
                  l10n.tripShare,
                  style: Theme.of(sheet).textTheme.titleMedium,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: Text(l10n.tripCopy),
              onTap: () async {
                Navigator.of(sheet).pop();
                await Clipboard.setData(ClipboardData(text: text));
                if (!await systemConfirmsCopy()) {
                  messenger.showMessage(l10n.tripCopied);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: Text(l10n.tripShareAction),
              onTap: () {
                Navigator.of(sheet).pop();
                unawaited(shareText(text, subject: subject));
              },
            ),
          ],
        ),
      ),
    );
  }
}
