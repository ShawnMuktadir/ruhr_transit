import 'dart:async';

import 'package:ruhr_transit/core/domain/transport_mode.dart';
import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop_repository.dart';

/// Hand-written fake: every call is recorded and stays pending until the
/// test completes it, so tests control the order in which answers arrive.
class FakeStopRepository implements StopRepository {
  final List<String> queries = [];
  final List<Completer<Result<List<Stop>>>> _pending = [];

  /// When set, calls complete immediately with this result instead.
  Result<List<Stop>>? autoReply;

  @override
  Future<Result<List<Stop>>> searchStops(String query) {
    queries.add(query);
    if (autoReply case final reply?) return Future.value(reply);
    final completer = Completer<Result<List<Stop>>>();
    _pending.add(completer);
    return completer.future;
  }

  /// Answers the [index]-th call (0 = first call made).
  void complete(int index, Result<List<Stop>> result) =>
      _pending[index].complete(result);
}

const bochumHbf = Stop(
  id: 'de:05911:5194',
  name: 'Hbf',
  fullName: 'Bochum, Hbf',
  locality: 'Bochum',
  latitude: 51.479466,
  longitude: 7.223335,
  modes: {TransportMode.train, TransportMode.subway, TransportMode.bus},
);

const dortmundHbf = Stop(
  id: 'de:05913:131',
  name: 'Hbf',
  fullName: 'Dortmund, Hbf',
  locality: 'Dortmund',
  latitude: 51.517,
  longitude: 7.459,
);
