import 'package:dio/dio.dart';
import 'package:ruhr_transit/core/config/app_config.dart';

/// Creates the [Dio] instance for all EFA requests.
///
/// Responses are read as plain text and decoded by `decodeEfaJson`, so a
/// malformed body becomes a parse failure in one place, independent of the
/// `Content-Type` the server sends.
Dio createEfaDio({String baseUrl = AppConfig.efaBaseUrl}) {
  return Dio(
    BaseOptions(
      // Dio appends request paths directly, so without the trailing slash
      // `.../openservice` + `XML_STOPFINDER_REQUEST` would run together.
      baseUrl: baseUrl.endsWith('/') ? baseUrl : '$baseUrl/',
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      responseType: ResponseType.plain,
      queryParameters: {'outputFormat': 'rapidJSON'},
    ),
  );
}

/// Creates the [Dio] instance for the weather (Bright Sky). Plain text
/// like EFA, decoded by the remote source.
Dio createBrightSkyDio({String baseUrl = AppConfig.brightSkyBaseUrl}) {
  return Dio(
    BaseOptions(
      baseUrl: baseUrl.endsWith('/') ? baseUrl : '$baseUrl/',
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      responseType: ResponseType.plain,
    ),
  );
}
