import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Talks to `MainActivity`, which opens pages of Android's Settings app.
const systemSettingsChannel = MethodChannel(
  'de.muktadir.ruhrtransit/system_settings',
);

/// Opens Android's accessibility settings, where the user can turn on
/// TalkBack; an app cannot turn it on itself. Falls back to the main
/// Settings page on phones without that page.
Future<void> openAccessibilitySettings() async {
  try {
    await systemSettingsChannel.invokeMethod<void>('accessibility');
  } on PlatformException catch (e) {
    debugPrint('Could not open the accessibility settings: $e');
  } on MissingPluginException {
    // Not on Android (tests, other platforms).
  }
}
