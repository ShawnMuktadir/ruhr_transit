import 'package:dio/dio.dart';
import 'package:ruhr_transit/core/error/failure.dart';
import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/core/network/efa_error_mapper.dart';
import 'package:ruhr_transit/core/network/efa_json.dart';

/// Runs [request], which fetches and reads an answer, and turns what can go
/// wrong into a [Failure]: no connection or a timeout, an error the server
/// reports, or an answer that cannot be read. The one place repositories
/// handle these.
Future<Result<T>> requestResult<T>(Future<T> Function() request) async {
  try {
    return Ok(await request());
  } on DioException catch (e) {
    return Err(failureFromDioException(e));
  } on EfaServerException catch (e) {
    return Err(ServerFailure(code: e.code, message: e.message));
  } on FormatException catch (e) {
    return Err(ParseFailure(e.message));
  }
}

/// Keeps only the newest of a series of requests: starting one cancels the
/// one still running, as only the newest answer matters (a new search, a
/// second refresh). Holding it makes a repository stateful, so such
/// repositories are registered as factories: one per page.
class LatestRequest {
  CancelToken? _running;

  Future<T> run<T>(Future<T> Function(CancelToken cancelToken) request) async {
    _running?.cancel();
    final cancelToken = _running = CancelToken();
    try {
      return await request(cancelToken);
    } finally {
      if (identical(_running, cancelToken)) _running = null;
    }
  }
}
