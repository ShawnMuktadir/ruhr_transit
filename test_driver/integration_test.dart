// Host side of `flutter drive`: saves the screenshots the app test takes
// into build/screenshots, which CI uploads.
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() => integrationDriver(
  onScreenshot: (name, bytes, [args]) async {
    final file = File('build/screenshots/$name.png');
    await file.create(recursive: true);
    await file.writeAsBytes(bytes);
    return true;
  },
);
