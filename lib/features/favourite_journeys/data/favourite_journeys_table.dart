import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:ruhr_transit/features/favourites/data/stop_json.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';

/// Saved journeys. A journey is identified by its two stop IDs, so the same
/// trip cannot be saved twice. The stops themselves are stored whole (as
/// JSON, in the same format as favourite stops), so the list shows without
/// a network request.
@DataClassName('FavouriteJourneyRow')
class FavouriteJourneys extends Table {
  TextColumn get fromId => text()();
  TextColumn get toId => text()();
  TextColumn get fromStop => text().map(const StopConverter())();
  TextColumn get toStop => text().map(const StopConverter())();
  TextColumn get label => text().nullable()();
  DateTimeColumn get savedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {fromId, toId};
}

class StopConverter extends TypeConverter<Stop, String> {
  const StopConverter();

  @override
  Stop fromSql(String fromDb) => stopFromJson(jsonDecode(fromDb));

  @override
  String toSql(Stop value) => jsonEncode(stopToJson(value));
}
