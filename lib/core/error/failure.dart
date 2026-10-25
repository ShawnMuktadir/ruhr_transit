/// Why an operation failed, in terms the domain and UI care about.
///
/// Sealed, so a `switch` over a [Failure] must handle every case, and the
/// compiler tells us when a new case is added. Data sources translate
/// exceptions (Dio, parsing) into one of these; nothing above the data
/// layer ever sees an exception.
sealed class Failure {
  const Failure();
}

/// The device is offline or the host could not be reached.
final class NetworkFailure extends Failure {
  const NetworkFailure();
}

/// The server did not answer within the configured timeout.
final class TimeoutFailure extends Failure {
  const TimeoutFailure();
}

/// The server answered, but with an error. EFA reports most errors with
/// HTTP 200 and a `systemMessages` entry, so [code] can be either an HTTP
/// status or an EFA message code.
final class ServerFailure extends Failure {
  const ServerFailure({this.code, this.message});

  final int? code;
  final String? message;
}

/// The response did not have the shape we expected.
final class ParseFailure extends Failure {
  const ParseFailure(this.message);

  final String message;
}
