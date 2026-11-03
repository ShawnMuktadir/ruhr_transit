import 'dart:async';

import 'package:ruhr_transit/core/connectivity/connectivity.dart';

/// Online until a test says otherwise with [set].
class FakeConnectivitySource implements ConnectivitySource {
  final _changes = StreamController<bool>.broadcast();
  var _online = true;

  void set({required bool online}) {
    _online = online;
    _changes.add(online);
  }

  @override
  Stream<bool> watch() async* {
    yield _online;
    yield* _changes.stream;
  }
}
