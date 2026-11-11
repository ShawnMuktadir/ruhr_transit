import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Talks to `MainActivity` on Android and `AppChannels.swift` on iOS, which
/// open the system's share sheet; no plugin needed.
const shareChannel = MethodChannel('de.muktadir.ruhrtransit/share');

/// Opens the phone's share sheet with [text], e.g. for a messenger or mail.
/// [subject] is the mail subject where the target app uses one.
Future<void> shareText(String text, {String? subject}) async {
  try {
    await shareChannel.invokeMethod<void>('text', {
      'text': text,
      'subject': subject,
    });
  } on PlatformException catch (e) {
    debugPrint('Could not share: $e');
  } on MissingPluginException {
    // Not on a phone (tests, other platforms).
  }
}

/// Whether the system itself confirms copied text: Android 13+ shows what
/// was copied, so the app adds no message of its own. iOS does not.
Future<bool> systemConfirmsCopy() async {
  if (defaultTargetPlatform != TargetPlatform.android) return false;
  try {
    return await shareChannel.invokeMethod<bool>('systemConfirmsCopy') ?? false;
  } on PlatformException catch (e) {
    debugPrint('Could not ask about copy confirmation: $e');
  } on MissingPluginException {
    // Not on a phone (tests).
  }
  return false;
}
