import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ruhr_transit/core/connectivity/offline_banner.dart';
import 'package:ruhr_transit/core/di/injection.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/core/widgets/clock_time.dart';
import 'package:ruhr_transit/features/nearby_stops/domain/location_source.dart';
import 'package:ruhr_transit/features/weather/domain/weather.dart';
import 'package:ruhr_transit/features/weather/domain/weather_repository.dart';
import 'package:ruhr_transit/features/weather/presentation/weather_cubit.dart';

/// The weather chip with its own cubit, for the planner.
class WeatherSection extends StatelessWidget {
  const WeatherSection({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) =>
        WeatherCubit(getIt<WeatherRepository>(), getIt<LocationSource>())
          ..load(),
    child: const WeatherChip(),
  );
}

/// The weather where the user is, or what is needed to show it. Tapping
/// refreshes, asks for the location or opens the right settings.
class WeatherChip extends StatefulWidget {
  const WeatherChip({super.key});

  @override
  State<WeatherChip> createState() => _WeatherChipState();
}

class _WeatherChipState extends State<WeatherChip> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Back from the settings or after a while away.
    _lifecycle = AppLifecycleListener(
      onResume: () => unawaited(context.read<WeatherCubit>().resumed()),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  /// Retries what failed when the phone is back online.
  @override
  Widget build(BuildContext context) => OnReconnect(
    onReconnect: () {
      final cubit = context.read<WeatherCubit>();
      if (cubit.state case WeatherUnavailable(
        problem: WeatherProblem.offline,
      )) {
        unawaited(cubit.load());
      }
    },
    child: Builder(builder: _build),
  );

  Widget _build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final state = context.watch<WeatherCubit>().state;

    final (Widget icon, String text, String? detail) = switch (state) {
      WeatherLoading() => (
        const SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        l10n.weatherLoading,
        null,
      ),
      WeatherShown(:final weather) => (
        Icon(_skyIcon(weather.sky), color: colors.primary),
        [
          if (weather.temperature case final t?)
            l10n.weatherTemperature(t.round() == 0 ? 0 : t.round()),
          if (l10n.weatherSky(weather.sky.name) case final sky
              when sky.isNotEmpty)
            sky,
        ].join(' · '),
        _outlook(context, l10n, weather.precipitation),
      ),
      WeatherNeedsPermission() => (
        Icon(Icons.location_disabled, color: colors.onSurfaceVariant),
        l10n.weatherNeedsLocation,
        null,
      ),
      WeatherLocationOff() => (
        Icon(Icons.location_off_outlined, color: colors.onSurfaceVariant),
        l10n.weatherLocationOff,
        null,
      ),
      WeatherUnavailable(:final problem) => (
        Icon(
          problem == WeatherProblem.offline
              ? Icons.cloud_off_outlined
              : Icons.error_outline,
          color: colors.onSurfaceVariant,
        ),
        switch (problem) {
          WeatherProblem.offline => l10n.weatherOffline,
          WeatherProblem.notHere => l10n.weatherNotHere,
          WeatherProblem.noPosition => l10n.weatherNoPosition,
          WeatherProblem.failed => l10n.weatherFailed,
        },
        null,
      ),
    };

    final chip = Material(
      color: colors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: state is WeatherLoading
            ? null
            : () => unawaited(context.read<WeatherCubit>().tap()),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                icon,
                const SizedBox(width: 12),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(text, style: theme.textTheme.bodyLarge),
                      if (detail != null)
                        Text(
                          detail,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.primary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          container: true,
          button: state is! WeatherLoading,
          onTapHint: state is WeatherShown ? l10n.weatherRefreshHint : null,
          child: chip,
        ),
        if (state is WeatherShown)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
            child: Text(
              l10n.weatherAttribution,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }

  static String? _outlook(
    BuildContext context,
    AppLocalizations l10n,
    PrecipitationOutlook? outlook,
  ) => switch (outlook) {
    null => null,
    PrecipitationOutlook(kind: PrecipitationKind.rain, isNow: true) =>
      l10n.weatherRainNow,
    PrecipitationOutlook(kind: PrecipitationKind.snow, isNow: true) =>
      l10n.weatherSnowNow,
    PrecipitationOutlook(kind: PrecipitationKind.rain, :final startsAt) =>
      l10n.weatherRainFrom(formatClockTime(context, startsAt)),
    PrecipitationOutlook(kind: PrecipitationKind.snow, :final startsAt) =>
      l10n.weatherSnowFrom(formatClockTime(context, startsAt)),
  };

  static IconData _skyIcon(WeatherSky sky) => switch (sky) {
    WeatherSky.clearDay => Icons.wb_sunny_outlined,
    WeatherSky.clearNight => Icons.nightlight_outlined,
    WeatherSky.partlyCloudyDay => Icons.wb_cloudy_outlined,
    WeatherSky.partlyCloudyNight => Icons.nights_stay_outlined,
    WeatherSky.cloudy => Icons.cloud_outlined,
    WeatherSky.fog => Icons.foggy,
    WeatherSky.wind => Icons.air,
    WeatherSky.rain => Icons.umbrella_outlined,
    WeatherSky.sleet || WeatherSky.hail => Icons.grain,
    WeatherSky.snow => Icons.ac_unit,
    WeatherSky.thunderstorm => Icons.thunderstorm_outlined,
    WeatherSky.unknown => Icons.thermostat,
  };
}
