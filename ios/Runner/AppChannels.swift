import Flutter
import UIKit

/// The app's own platform channels, the iOS side of what `MainActivity.kt`
/// registers on Android. `app_locale` has no iOS side: iOS lets no app set
/// its own language, so the app keeps its choice in shared preferences.
enum AppChannels {
  static func register(with registrar: FlutterPluginRegistrar) {
    let messenger = registrar.messenger()

    FlutterEventChannel(name: "de.muktadir.ruhrtransit/connectivity", binaryMessenger: messenger)
      .setStreamHandler(ConnectivityStreamHandler())

    FlutterMethodChannel(name: "de.muktadir.ruhrtransit/system_settings", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        switch call.method {
        case "accessibility":
          // iOS lets apps open only their own page in Settings; the
          // accessibility settings are one step back from there.
          if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
          }
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
  }
}
