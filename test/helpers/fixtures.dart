import 'dart:io';

import 'package:ruhr_transit/core/network/efa_json.dart';

/// Raw body of a recorded EFA response from `test/fixtures/efa/`.
/// `flutter test` runs from the project root, so a relative path works.
String readEfaFixture(String name) =>
    File('test/fixtures/efa/$name.json').readAsStringSync();

Map<String, Object?> readEfaFixtureJson(String name) =>
    decodeEfaJson(readEfaFixture(name));
