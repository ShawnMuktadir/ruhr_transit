import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/features/weather/domain/weather.dart';

abstract interface class WeatherRepository {
  /// The current weather near the point, with the next hours' rain or snow.
  ///
  /// Outside Germany there is no data: [ServerFailure] with code 404.
  Future<Result<Weather>> weatherAt({
    required double latitude,
    required double longitude,
  });
}
