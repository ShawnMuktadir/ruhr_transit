import 'package:dio/dio.dart';
import 'package:ruhr_transit/core/error/failure.dart';

/// Translates a [DioException] into a [Failure], so nothing above the data
/// layer depends on Dio.
Failure failureFromDioException(DioException exception) {
  return switch (exception.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.transformTimeout => const TimeoutFailure(),
    DioExceptionType.badResponse => ServerFailure(
      code: exception.response?.statusCode,
      message: exception.response?.statusMessage,
    ),
    DioExceptionType.cancel => const CancelledFailure(),
    // Dio reports DNS errors and refused connections as connectionError.
    // unknown covers sockets that close mid-response; badCertificate is
    // most often a captive portal (e.g. station Wi-Fi). From the user's
    // point of view all of these mean "no working connection".
    DioExceptionType.connectionError ||
    DioExceptionType.badCertificate ||
    DioExceptionType.unknown => const NetworkFailure(),
  };
}
