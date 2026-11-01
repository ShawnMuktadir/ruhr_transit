// Captures real VRR EFA responses into test/fixtures/efa/ so that mapper and
// repository tests run against real data instead of hand-written JSON.
//
// Usage (from the project root):
//   dart run tool/capture_efa_fixtures.dart
//   dart run -DEFA_BASE_URL=https://openservice-test.vrr.de/openservice tool/capture_efa_fixtures.dart
//
// Re-run only when the API shape needs re-checking. Live data changes every
// minute, so tests must not depend on specific times or lines.

// A command-line tool, so printing to stdout is the intended output.
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:ruhr_transit/core/config/app_config.dart';

/// Bochum Hbf and Dortmund Hbf, as returned by XML_STOPFINDER_REQUEST.
const _bochumHbf = 'de:05911:5194';
const _dortmundHbf = 'de:05913:131';
const _wgs84 = 'WGS84[dd.ddddd]';

final Map<String, (String, Map<String, String>)> _requests = {
  'stopfinder_bochum_hbf': (
    'XML_STOPFINDER_REQUEST',
    {'type_sf': 'any', 'name_sf': 'Bochum Hbf', 'coordOutputFormat': _wgs84},
  ),
  'stopfinder_no_match': (
    'XML_STOPFINDER_REQUEST',
    {'type_sf': 'any', 'name_sf': 'xqzzqxv', 'coordOutputFormat': _wgs84},
  ),
  'coord_nearby_bochum_hbf': (
    'XML_COORD_REQUEST',
    {
      // EFA expects longitude first: lon:lat:format
      'coord': '7.223335:51.479466:$_wgs84',
      'coordOutputFormat': _wgs84,
      'inclFilter': '1',
      'type_1': 'STOP',
      'radius_1': '600',
      'max': '10',
    },
  ),
  // A point in the North Sea: no stops within the radius.
  'coord_nearby_none': (
    'XML_COORD_REQUEST',
    {
      'coord': '4.0:54.5:$_wgs84',
      'coordOutputFormat': _wgs84,
      'inclFilter': '1',
      'type_1': 'STOP',
      'radius_1': '1000',
      'max': '20',
    },
  ),
  'dm_bochum_hbf': (
    'XML_DM_REQUEST',
    {
      'mode': 'direct',
      'type_dm': 'stop',
      'name_dm': _bochumHbf,
      'useRealtime': '1',
      'depType': 'stopEvents',
      'limit': '20',
      'coordOutputFormat': _wgs84,
    },
  ),
  'trip_bochum_dortmund': (
    'XML_TRIP_REQUEST2',
    {
      'type_origin': 'any',
      'name_origin': _bochumHbf,
      'type_destination': 'any',
      'name_destination': _dortmundHbf,
      'useRealtime': '1',
      'calcNumberOfTrips': '3',
      'coordOutputFormat': _wgs84,
    },
  ),
};

Future<void> main() async {
  final outDir = Directory('test/fixtures/efa')..createSync(recursive: true);
  final client = HttpClient()..connectionTimeout = AppConfig.connectTimeout;
  const encoder = JsonEncoder.withIndent('  ');

  try {
    for (final MapEntry(key: name, value: (endpoint, params))
        in _requests.entries) {
      final uri = Uri.parse(
        '${AppConfig.efaBaseUrl}/$endpoint',
      ).replace(queryParameters: {'outputFormat': 'rapidJSON', ...params});
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.userAgentHeader, 'RuhrTransit-dev/0.1');
      final response = await request.close().timeout(AppConfig.receiveTimeout);
      final body = await response.transform(utf8.decoder).join();

      final json = jsonDecode(body) as Map<String, Object?>;
      File(
        '${outDir.path}/$name.json',
      ).writeAsStringSync('${encoder.convert(json)}\n');

      final messages = json['systemMessages'] ?? const <Object?>[];
      print(
        '$name: HTTP ${response.statusCode}, '
        '${body.length} chars, systemMessages=${jsonEncode(messages)}',
      );
    }
  } finally {
    client.close();
  }
}
