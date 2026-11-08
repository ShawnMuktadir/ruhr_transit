import Flutter
import Network

/// Sends `true` while the phone has a usable network and `false` otherwise,
/// first the current state, then every change. The iOS side of
/// `ConnectivityStreamHandler.kt`.
///
/// Unlike Android, iOS does not test the connection: a Wi-Fi with a captive
/// portal (station Wi-Fi before logging in) counts as online, and requests
/// fail on their own there.
final class ConnectivityStreamHandler: NSObject, FlutterStreamHandler {
  private var monitor: NWPathMonitor?
  private var last: Bool?

  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    let monitor = NWPathMonitor()
    monitor.pathUpdateHandler = { [weak self] path in
      let online = path.status == .satisfied
      DispatchQueue.main.async {
        // Updates repeat themselves; Flutter only needs changes, and none
        // after onCancel.
        guard let self, self.monitor != nil, online != self.last else { return }
        self.last = online
        events(online)
      }
    }
    self.monitor = monitor
    // The first update is the current state.
    monitor.start(queue: DispatchQueue(label: "de.muktadir.ruhrtransit.connectivity"))
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    monitor?.cancel()
    monitor = nil
    last = nil
    return nil
  }
}
