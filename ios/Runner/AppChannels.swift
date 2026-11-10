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

    FlutterMethodChannel(name: "de.muktadir.ruhrtransit/share", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        switch call.method {
        case "text":
          let arguments = call.arguments as? [String: Any]
          AppChannels.shareText(
            arguments?["text"] as? String ?? "",
            subject: arguments?["subject"] as? String
          )
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
  }

  /// The iOS share sheet, e.g. for Messages or Mail, over the page on top.
  private static func shareText(_ text: String, subject: String?) {
    guard let top = topViewController() else { return }
    let sheet = UIActivityViewController(
      activityItems: [ShareTextItem(text: text, subject: subject)],
      applicationActivities: nil)
    // Needed where the sheet opens as a popover (iPad); harmless elsewhere.
    sheet.popoverPresentationController?.sourceView = top.view
    sheet.popoverPresentationController?.sourceRect = CGRect(
      x: top.view.bounds.midX, y: top.view.bounds.midY, width: 0, height: 0)
    sheet.popoverPresentationController?.permittedArrowDirections = []
    top.present(sheet, animated: true)
  }

  /// The view controller on top of the app's key window, so the sheet opens
  /// over anything already presented.
  private static func topViewController() -> UIViewController? {
    let window = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .first(where: \.isKeyWindow)
    var top = window?.rootViewController
    while let presented = top?.presentedViewController {
      top = presented
    }
    return top
  }
}

/// Shared text with a subject, which Mail uses for the mail's subject.
private final class ShareTextItem: NSObject, UIActivityItemSource {
  private let text: String
  private let subject: String?

  init(text: String, subject: String?) {
    self.text = text
    self.subject = subject
  }

  func activityViewControllerPlaceholderItem(_ controller: UIActivityViewController) -> Any {
    text
  }

  func activityViewController(
    _ controller: UIActivityViewController,
    itemForActivityType activityType: UIActivity.ActivityType?
  ) -> Any? {
    text
  }

  func activityViewController(
    _ controller: UIActivityViewController,
    subjectForActivityType activityType: UIActivity.ActivityType?
  ) -> String {
    subject ?? ""
  }
}
