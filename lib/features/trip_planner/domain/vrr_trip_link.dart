import 'package:ruhr_transit/features/stop_search/domain/stop.dart';

/// A link to VRR's web journey planner with the same start, destination and
/// departure time, so whoever receives a shared trip can open it in any
/// browser, with VRR's live data.
///
/// Stops go by their global ID; addresses and places, which have none that
/// the web planner reads, by their coordinates. [departure] is sent in the
/// phone's local time, as the app's searches are (see README, Known
/// limits).
Uri vrrTripLink({
  required Stop from,
  required Stop to,
  required DateTime departure,
  required String languageCode,
}) {
  final local = departure.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return Uri.https('efa.vrr.de', '/vrr/XSLT_TRIP_REQUEST2', {
    'language': languageCode,
    'sessionID': '0',
    ..._place('origin', from),
    ..._place('destination', to),
    'itdDate': '${local.year}${two(local.month)}${two(local.day)}',
    'itdTime': '${two(local.hour)}${two(local.minute)}',
    'itdTripDateTimeDepArr': 'dep',
  });
}

Map<String, String> _place(String role, Stop stop) =>
    stop.kind == LocationKind.stop
    ? {'type_$role': 'stop', 'name_$role': stop.id}
    : {
        'type_$role': 'coord',
        // EFA's coordinate format: longitude first.
        'name_$role':
            '${stop.longitude.toStringAsFixed(5)}:'
            '${stop.latitude.toStringAsFixed(5)}:WGS84[dd.ddddd]',
      };
