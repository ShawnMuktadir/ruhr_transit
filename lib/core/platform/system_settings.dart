import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Talks to `MainActivity` on Android and `AppChannels.swift` on iOS, which
/// open the system's Settings app.
const systemSettingsChannel = MethodChannel(
  'de.muktadir.ruhrtransit/system_settings',
);

/// Opens Android's accessibility settings, where the user can turn on
/// TalkBack; an app cannot turn it on itself. Falls back to the main
/// Settings page on phones without that page.
///
/// iOS lets apps open only their own page in Settings; the user goes on
/// from there to Accessibility.
Future<void> openAccessibilitySettings() async {
  try {
    await systemSettingsChannel.invokeMethod<void>('accessibility');
  } on PlatformException catch (e) {
    debugPrint('Could not open the accessibility settings: $e');
  } on MissingPluginException {
    // Not on a phone (tests, other platforms).
  }
}
