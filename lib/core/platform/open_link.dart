import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Talks to `MainActivity` on Android and `AppChannels.swift` on iOS, which
/// open web links; no plugin needed.
const linksChannel = MethodChannel('de.muktadir.ruhrtransit/links');

/// Opens [link] in the app that handles it, or the browser. False when
/// nothing could open it.
Future<bool> openLink(Uri link) async {
  try {
    return await linksChannel.invokeMethod<bool>('open', {
          'url': link.toString(),
        }) ??
        false;
  } on PlatformException catch (e) {
    debugPrint('Could not open $link: $e');
  } on MissingPluginException {
    // Not on a phone (tests, other platforms).
  }
  return false;
}
