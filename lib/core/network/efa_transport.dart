import 'package:ruhr_transit/core/domain/transport_mode.dart';
import 'package:ruhr_transit/core/network/efa_product.dart';

/// Readers for fields that departure monitor and trip responses share, so
/// both show lines, times and notes the same way.

/// Most lines have `disassembledName` (`RE16`); long-distance trains don't,
/// so `number` (`945`) and then `name` are the fallbacks. Some long-distance
/// trains have none of these (seen live: a DB high-speed train to Stuttgart),
/// and only the product name (`Zug`) is left. `tripCode` is no substitute: it
/// is not the train number.
///
/// Long-distance trains send only their number (`905`); their type
/// (`properties.trainType`, e.g. `ICE`, `FLX`, `EN`) goes in front of it.
String readEfaLine(Map<String, Object?> transportation) {
  if (readNonEmptyString(transportation['disassembledName']) case final line?) {
    return line;
  }
  if (readNonEmptyString(transportation['number']) case final number?) {
    final type = switch (transportation['properties']) {
      {'trainType': final String type} when type.isNotEmpty => type,
      _ => null,
    };
    return type != null && RegExp(r'^\d+$').hasMatch(number)
        ? '$type $number'
        : number;
  }
  if (readNonEmptyString(transportation['name']) case final line?) return line;
  if (transportation['product'] case {
    'name': final String product,
  } when product.isNotEmpty) {
    return product;
  }
  throw const FormatException('Transportation without line name');
}

/// Null when EFA sends a product class the app does not know.
TransportMode? readEfaMode(Map<String, Object?> transportation) =>
    switch (transportation['product']) {
      {'class': final int productClass} => transportModeForProductClass(
        productClass,
      ),
      _ => null,
    };

/// EFA sends UTC timestamps like `2026-10-25T17:13:00Z`.
DateTime? readEfaTime(Object? value) =>
    value is String ? DateTime.parse(value) : null;

String? readNonEmptyString(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

/// Only realtime incident hints (`RTIncidentCall`). `Timetable` hints are
/// amenities like "WLAN verfügbar" that would bury the important ones.
List<String> readEfaRealtimeNotes(Object? hints) {
  if (hints is! List<Object?>) return const [];
  return {
    for (final hint in hints)
      if (hint case {
        'type': 'RTIncidentCall',
        'content': final String content,
      } when content.isNotEmpty)
        content,
  }.toList();
}

/// A stop name, trimmed and with single spaces: EFA sometimes sends two
/// ("Bochum  Gesundheitscampus"). Null when missing or empty.
String? readEfaStopName(Object? json) => switch (json) {
  final String name when name.trim().isNotEmpty => name.trim().replaceAll(
    RegExp(r'\s+'),
    ' ',
  ),
  _ => null,
};
