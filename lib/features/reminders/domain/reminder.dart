import 'package:ruhr_transit/core/domain/transport_mode.dart';
import 'package:ruhr_transit/features/departures/domain/departure.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';
import 'package:ruhr_transit/features/trip_planner/domain/journey.dart';
import 'package:ruhr_transit/features/trip_planner/domain/trip_query.dart';
import 'package:ruhr_transit/features/trip_planner/domain/vehicle_run.dart';
import 'package:ruhr_transit/features/trip_planner/domain/walk_to_stop.dart';

/// How long before leaving a reminder can come.
const reminderLeads = [
  Duration(minutes: 5),
  Duration(minutes: 10),
  Duration(minutes: 15),
  Duration(minutes: 30),
];

/// A notification to leave in time for the first ride of a journey. Holds
/// everything the alarm needs while the app is closed.
class Reminder {
  const Reminder({
    required this.id,
    required this.key,
    required this.line,
    required this.stopName,
    required this.plannedDeparture,
    required this.departure,
    required this.walkBefore,
    required this.lead,
    required this.languageCode,
    required this.use24HourFormat,
    this.mode,
    this.platform,
    this.runKey,
    this.originStopId,
    this.originParentId,
    this.boardStop,
    this.tripFrom,
    this.tripTo,
  });

  /// A reminder for one departure at [stop]: nothing to walk.
  static Reminder forDeparture(
    Departure departure,
    Stop stop, {
    required int id,
    required Duration lead,
    required String languageCode,
    required bool use24HourFormat,
  }) => Reminder(
    id: id,
    key: keyOfDeparture(departure, stop),
    line: departure.line,
    mode: departure.mode,
    stopName: stop.fullName,
    platform: departure.platform,
    plannedDeparture: departure.plannedTime,
    departure: departure.time,
    walkBefore: Duration.zero,
    lead: lead,
    languageCode: languageCode,
    use24HourFormat: use24HourFormat,
    runKey: departure.runKey,
    originStopId: departure.runKey?.stopId,
    boardStop: stop,
  );

  /// Tells whether a departure already has a reminder.
  static String keyOfDeparture(Departure departure, Stop stop) =>
      '${departure.line}|${stop.id}|'
      '${departure.plannedTime.toIso8601String()}';

  /// The first ride of [journey], or null when it is only a walk.
  static Reminder? forJourney(
    Journey journey, {
    required int id,
    required Duration lead,
    required String languageCode,
    required bool use24HourFormat,
    TripQuery? query,
  }) {
    for (final leg in journey.legs) {
      if (leg is TransitLeg) {
        return Reminder(
          id: id,
          key: keyOf(journey)!,
          line: leg.line,
          mode: leg.mode,
          stopName: leg.origin.name,
          platform: leg.origin.platform,
          plannedDeparture: leg.origin.plannedTime,
          departure: leg.origin.time,
          walkBefore: leg.origin.time.difference(journey.departure.time),
          lead: lead,
          languageCode: languageCode,
          use24HourFormat: use24HourFormat,
          runKey: leg.runKey,
          originStopId: leg.originId?.id,
          originParentId: leg.originId?.parentId,
          boardStop: boardingStopOf(leg),
          tripFrom: query?.from,
          tripTo: query?.to,
        );
      }
    }
    return null;
  }

  /// Tells whether a journey already has a reminder; null without a ride.
  static String? keyOf(Journey journey) {
    for (final leg in journey.legs) {
      if (leg is TransitLeg) {
        return '${leg.line}|${leg.origin.name}|'
            '${leg.origin.plannedTime.toIso8601String()}';
      }
    }
    return null;
  }

  final int id;
  final String key;
  final String line;
  final TransportMode? mode;
  final String stopName;
  final String? platform;

  /// In UTC, from the timetable.
  final DateTime plannedDeparture;

  /// In UTC, the best known departure of the ride; later with a delay.
  final DateTime departure;

  /// From leaving to the ride's departure: the walk to the stop, if any.
  final Duration walkBefore;

  /// How long before leaving the notification comes.
  final Duration lead;

  /// The notification is written without a screen, so it remembers the
  /// language and clock format it was set in.
  final String languageCode;
  final bool use24HourFormat;

  /// For asking VRR about delays; null when the ride has no known run.
  final RunKey? runKey;
  final String? originStopId;
  final String? originParentId;

  /// Whose departures tapping the notification opens; null just opens the
  /// app.
  final Stop? boardStop;

  /// What was searched, to find the trip again when the notification is
  /// tapped; null for a departure.
  final Stop? tripFrom;
  final Stop? tripTo;

  /// What tapping the notification opens.
  ReminderOpening get opening => ReminderOpening(
    key: key,
    stop: boardStop,
    from: tripFrom,
    to: tripTo,
    // A little before the ride's timetabled start, so the search finds it
    // also when it is late.
    searchFrom: plannedDeparture.subtract(
      walkBefore + const Duration(minutes: 2),
    ),
  );

  /// When the user has to leave.
  DateTime get leaveAt => departure.subtract(walkBefore);

  /// When the notification is due.
  DateTime get notifyAt => leaveAt.subtract(lead);

  Reminder withDeparture(DateTime departure) => Reminder(
    id: id,
    key: key,
    line: line,
    mode: mode,
    stopName: stopName,
    platform: platform,
    plannedDeparture: plannedDeparture,
    departure: departure,
    walkBefore: walkBefore,
    lead: lead,
    languageCode: languageCode,
    use24HourFormat: use24HourFormat,
    runKey: runKey,
    originStopId: originStopId,
    originParentId: originParentId,
    boardStop: boardStop,
    tripFrom: tripFrom,
    tripTo: tripTo,
  );
}

/// What a tapped notification opens: the trip when it can be found again,
/// else the stop's departures, else just the app.
class ReminderOpening {
  const ReminderOpening({
    required this.key,
    required this.searchFrom,
    this.stop,
    this.from,
    this.to,
  });

  /// [Reminder.key], to recognise the trip among the results.
  final String key;

  /// In UTC.
  final DateTime searchFrom;
  final Stop? stop;
  final Stop? from;
  final Stop? to;
}
