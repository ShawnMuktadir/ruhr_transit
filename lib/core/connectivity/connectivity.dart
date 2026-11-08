import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Whether the phone reaches the internet, as the system reports it.
abstract interface class ConnectivitySource {
  /// The current state first, then every change.
  Stream<bool> watch();
}

/// [ConnectivitySource] through the app's own platform code, no plugin
/// needed: `ConnectivityStreamHandler.kt` on Android and
/// `ConnectivityStreamHandler.swift` on iOS.
class PlatformConnectivitySource implements ConnectivitySource {
  const PlatformConnectivitySource();

  static const _channel = EventChannel('de.muktadir.ruhrtransit/connectivity');

  @override
  Stream<bool> watch() =>
      _channel.receiveBroadcastStream().map((online) => online == true);
}

/// `true` while online. Starts online, so nothing flashes "offline" before
/// the system answered; requests fail on their own if it is not.
class ConnectivityCubit extends Cubit<bool> {
  ConnectivityCubit(ConnectivitySource source) : super(true) {
    _subscription = source.watch().listen(
      emit,
      onError: (Object e) => debugPrint('No connectivity updates: $e'),
    );
  }

  late final StreamSubscription<bool> _subscription;

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
