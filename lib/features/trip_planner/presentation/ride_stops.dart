import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ruhr_transit/core/domain/transport_mode.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/core/widgets/platform_chip.dart';
import 'package:ruhr_transit/core/widgets/transport_mode_icon.dart';
import 'package:ruhr_transit/features/trip_planner/domain/journey.dart';
import 'package:ruhr_transit/features/trip_planner/domain/vehicle_run.dart';
import 'package:ruhr_transit/features/trip_planner/domain/vehicle_run_repository.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/trip_widgets.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/vehicle_run_cubit.dart';

/// The stops of one ride. With the vehicle's whole run loaded: a timeline
/// from its first to its last stop, showing where it is now. Until then,
/// or if the run cannot be loaded: boarding and alighting stop with the
/// stops in between on request.
class RideStops extends StatelessWidget {
  const RideStops(this.leg, {this.runs, this.now = DateTime.now, super.key});

  final TransitLeg leg;

  /// Makes the repository for this ride's run; null shows no run.
  final VehicleRunRepository Function()? runs;

  /// The clock the vehicle's position is calculated for.
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) {
    final plain = _PlainStops(leg);
    final key = leg.runKey;
    final runs = this.runs;
    if (key == null || runs == null) return plain;
    return BlocProvider(
      create: (_) => VehicleRunCubit(runs(), key, now: now)..start(),
      child: BlocBuilder<VehicleRunCubit, VehicleRunState>(
        builder: (context, state) {
          if (state is! VehicleRunLoaded) return plain;
          final run = state.run;
          final board = run.indexOf(
            leg.originId?.id ?? key.stopId,
            parentId: leg.originId?.parentId,
          );
          final alight = switch (leg.destinationId) {
            final ref? => run.indexOf(ref.id, parentId: ref.parentId),
            null => null,
          };
          // A run that does not contain the ride as expected is not shown
          // rather than shown wrong.
          if (board == null || alight == null || board >= alight) {
            return plain;
          }
          return RunTimeline(
            run: run,
            board: board,
            alight: alight,
            position: state.position,
            now: state.now,
            mode: leg.mode,
          );
        },
      ),
    );
  }
}

class _PlainStops extends StatelessWidget {
  const _PlainStops(this.leg);

  final TransitLeg leg;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StopRow(leg.origin, mode: leg.mode),
        if (leg.intermediateStops.isNotEmpty)
          _ExpandToggle(
            label: AppLocalizations.of(
              context,
            ).tripIntermediateStops(leg.intermediateStops.length),
            expandedChildren: [
              for (final stop in leg.intermediateStops)
                StopRow(stop, mode: leg.mode, compact: true),
            ],
          ),
        StopRow(leg.destination, mode: leg.mode),
      ],
    );
  }
}

/// A row that shows or hides [expandedChildren] below it.
class _ExpandToggle extends StatefulWidget {
  const _ExpandToggle({
    required this.label,
    required this.expandedChildren,
    this.leading,
  });

  final String label;
  final List<Widget> expandedChildren;

  /// Left of the row, e.g. the timeline's rail.
  final Widget? leading;

  @override
  State<_ExpandToggle> createState() => _ExpandToggleState();
}

class _ExpandToggleState extends State<_ExpandToggle> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    final toggle = Semantics(
      // Its own node, so TalkBack reads it as a button with its state.
      container: true,
      button: true,
      expanded: _expanded,
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                color: color,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  widget.label,
                  style: theme.textTheme.bodyMedium?.copyWith(color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.leading case final leading?)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                leading,
                Expanded(child: toggle),
              ],
            ),
          )
        else
          toggle,
        if (_expanded) ...widget.expandedChildren,
      ],
    );
  }
}

/// The vehicle's whole run as a timeline: a line with one dot per stop,
/// filled up to where the vehicle is now, like an order tracker.
class RunTimeline extends StatelessWidget {
  const RunTimeline({
    required this.run,
    required this.board,
    required this.alight,
    required this.position,
    required this.now,
    this.mode,
    super.key,
  });

  final VehicleRun run;

  /// Indexes in [run] of the stops where the user gets on and off.
  final int board;
  final int alight;

  final RunPosition position;
  final DateTime now;
  final TransportMode? mode;

  /// The vehicle's place as a number: stop i is i, between i and i + 1 is
  /// i + 0.5. Before the start -0.5, after the end past the last stop.
  double get _place => switch (position) {
    RunNotStarted() => -0.5,
    RunAtStop(:final index) => index.toDouble(),
    RunBetween(:final from) => from + 0.5,
    RunEnded() => run.stops.length.toDouble(),
  };

  @override
  Widget build(BuildContext context) {
    final place = _place;
    final last = run.stops.length - 1;

    Widget row(int i) => _TimelineStop(
      stop: run.stops[i],
      mode: mode,
      // The line above the dot is passed once the vehicle got here, the
      // line below once it left.
      topPassed: i == 0 ? null : place >= i,
      bottomPassed: i == last ? null : place > i,
      dot: switch (place.compareTo(i)) {
        > 0 => _Dot.passed,
        0 => _Dot.current,
        _ => _Dot.upcoming,
      },
      tag: switch (i) {
        _ when i == board => AppLocalizations.of(context).runBoard,
        _ when i == alight => AppLocalizations.of(context).runAlight,
        _ => null,
      },
      // Outside the ride: muted, so the user's part stands out.
      muted: i < board || i > alight,
      compact: i != board && i != alight,
    );

    List<Widget> rows(int from, int to) => [
      for (var i = from; i <= to; i++) ...[
        row(i),
        if (position case RunBetween(from: final at) when at == i && i < to)
          _VehicleMarker(mode: mode),
      ],
    ];

    final beforeCount = board;
    final afterCount = last - alight;
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RunStatus(run: run, position: position, now: now),
        if (beforeCount > 0)
          _ExpandToggle(
            label: l10n.runStopsBefore(beforeCount),
            // Collapsed even while the vehicle is in this part: a long run
            // (e.g. the RE6 from Minden) would push the user's own stops
            // far down. The status line says where it is.
            leading: _Rail(
              topPassed: null,
              bottomPassed: place >= board,
              dot: _Dot.none,
            ),
            expandedChildren: rows(0, board - 1),
          ),
        // Between the last stop before boarding and boarding itself.
        if (position case RunBetween(from: final at) when at == board - 1)
          _VehicleMarker(mode: mode),
        ...rows(board, alight),
        if (position case RunBetween(from: final at) when at == alight)
          _VehicleMarker(mode: mode),
        if (afterCount > 0)
          _ExpandToggle(
            label: l10n.runStopsAfter(afterCount),
            leading: _Rail(
              topPassed: place > alight,
              bottomPassed: null,
              dot: _Dot.none,
            ),
            expandedChildren: rows(alight + 1, last),
          ),
      ],
    );
  }
}

/// "Jetzt zwischen Essen Eiberg und Essen Steele Ost", and whether that
/// comes from live data or only the timetable.
class _RunStatus extends StatelessWidget {
  const _RunStatus({
    required this.run,
    required this.position,
    required this.now,
  });

  final VehicleRun run;
  final RunPosition position;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final stops = run.stops;
    final text = switch (position) {
      RunNotStarted() => switch (stops.first.departure
          .difference(now)
          .inMinutes) {
        < 1 => l10n.runDepartsNow(stops.first.name),
        final minutes => l10n.runDepartsIn(minutes, stops.first.name),
      },
      RunAtStop(:final index) => l10n.runAt(stops[index].name),
      RunBetween(:final from, :final to) => l10n.runBetween(
        stops[from].name,
        stops[to].name,
      ),
      RunEnded() => l10n.runEnded,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            run.isRealtime ? Icons.sensors : Icons.schedule,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                if (!run.isRealtime)
                  Text(l10n.runByTimetable, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineStop extends StatelessWidget {
  const _TimelineStop({
    required this.stop,
    required this.topPassed,
    required this.bottomPassed,
    required this.dot,
    required this.muted,
    required this.compact,
    this.tag,
    this.mode,
  });

  final RunStop stop;
  final bool? topPassed;
  final bool? bottomPassed;
  final _Dot dot;
  final bool muted;
  final bool compact;
  final String? tag;
  final TransportMode? mode;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Rail(
            topPassed: topPassed,
            bottomPassed: bottomPassed,
            dot: dot,
            emphasised: tag != null,
          ),
          Expanded(
            child: StopRow(
              _asTripStop(stop),
              mode: mode,
              compact: compact,
              muted: muted,
              tag: tag,
            ),
          ),
        ],
      ),
    );
  }

  /// The time a passenger cares about: the departure, at the last stop
  /// the arrival.
  static TripStop _asTripStop(RunStop stop) {
    final departs = stop.departurePlanned != null;
    return TripStop(
      name: stop.name,
      plannedTime: departs ? stop.departurePlanned! : stop.arrivalPlanned!,
      estimatedTime: departs ? stop.departureEstimated : stop.arrivalEstimated,
      platform: stop.platform,
      plannedPlatform: stop.plannedPlatform,
    );
  }
}

/// Between two stops: the vehicle, on the line.
class _VehicleMarker extends StatelessWidget {
  const _VehicleMarker({this.mode});

  final TransportMode? mode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: _Rail.width,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const _Rail(
                  topPassed: true,
                  bottomPassed: false,
                  dot: _Dot.none,
                ),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: colors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: switch (mode) {
                    final mode? => TransportModeIcon(
                      mode,
                      size: 14,
                      color: colors.onPrimary,
                    ),
                    null => Icon(
                      Icons.directions_transit,
                      size: 14,
                      color: colors.onPrimary,
                    ),
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 32),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  AppLocalizations.of(context).runVehicleHere,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _Dot { none, passed, current, upcoming }

/// The line left of the stops, with the stop's dot. [topPassed] and
/// [bottomPassed] colour the line above and below the dot; null draws
/// none (first and last stop).
class _Rail extends StatelessWidget {
  const _Rail({
    required this.topPassed,
    required this.bottomPassed,
    required this.dot,
    this.emphasised = false,
  });

  static const width = 28.0;

  final bool? topPassed;
  final bool? bottomPassed;
  final _Dot dot;

  /// Boarding and alighting: a bigger dot.
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      // Decoration only: the stop row says everything.
      child: ExcludeSemantics(
        child: CustomPaint(
          painter: _RailPainter(
            topPassed: topPassed,
            bottomPassed: bottomPassed,
            dot: dot,
            emphasised: emphasised,
            passed: colors.primary,
            upcoming: colors.outlineVariant,
            background: colors.surface,
          ),
        ),
      ),
    );
  }
}

class _RailPainter extends CustomPainter {
  _RailPainter({
    required this.topPassed,
    required this.bottomPassed,
    required this.dot,
    required this.emphasised,
    required this.passed,
    required this.upcoming,
    required this.background,
  });

  final bool? topPassed;
  final bool? bottomPassed;
  final _Dot dot;
  final bool emphasised;
  final Color passed;
  final Color upcoming;
  final Color background;

  /// Level with the first line of the stop's text.
  static const _dotY = 14.0;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    final dotY = dot == _Dot.none ? size.height / 2 : _dotY;
    Paint line(bool isPassed) => Paint()
      ..color = isPassed ? passed : upcoming
      ..strokeWidth = 3;
    if (topPassed case final isPassed?) {
      canvas.drawLine(Offset(x, 0), Offset(x, dotY), line(isPassed));
    }
    if (bottomPassed case final isPassed?) {
      canvas.drawLine(Offset(x, dotY), Offset(x, size.height), line(isPassed));
    }
    final radius = switch (dot) {
      _Dot.none => 0.0,
      _Dot.current => 8.0,
      _ => emphasised ? 7.0 : 5.0,
    };
    if (radius == 0) return;
    final center = Offset(x, dotY);
    switch (dot) {
      case _Dot.passed:
        canvas.drawCircle(center, radius, Paint()..color = passed);
      case _Dot.current:
        canvas
          ..drawCircle(
            center,
            radius + 3,
            Paint()..color = passed.withValues(alpha: 0.3),
          )
          ..drawCircle(center, radius, Paint()..color = passed);
      case _Dot.upcoming:
        canvas
          ..drawCircle(center, radius, Paint()..color = background)
          ..drawCircle(
            center,
            radius,
            Paint()
              ..color = emphasised ? passed : upcoming
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
      case _Dot.none:
        break;
    }
  }

  @override
  bool shouldRepaint(_RailPainter old) =>
      old.topPassed != topPassed ||
      old.bottomPassed != bottomPassed ||
      old.dot != dot ||
      old.emphasised != emphasised ||
      old.passed != passed ||
      old.upcoming != upcoming;
}

/// `17:14 +3   Bochum Hbf`, with a [Gleis 8] chip under the name.
class StopRow extends StatelessWidget {
  const StopRow(
    this.stop, {
    this.mode,
    this.compact = false,
    this.muted = false,
    this.tag,
    super.key,
  });

  final TripStop stop;

  /// Of the leg, so a bus stop gets "Steig" instead of "Gleis".
  final TransportMode? mode;

  /// A stop in between: smaller, so origin and destination stand out.
  final bool compact;

  /// Outside the user's ride, e.g. before boarding.
  final bool muted;

  /// Shown above the name, e.g. "Einstieg".
  final String? tag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = compact
        ? theme.textTheme.bodyMedium
        : theme.textTheme.bodyLarge;
    final style = muted
        ? base?.copyWith(color: theme.colorScheme.onSurfaceVariant)
        : base;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A minimum, not a fixed width: "10:14 AM +12" must still fit.
          ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: 112,
              // Leaves the stop name room at large font sizes.
              maxWidth: MediaQuery.sizeOf(context).width * 0.35,
            ),
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TripTimeText(stop, style: style),
            ),
          ),
          // The platform goes under the name, so a long name and platform
          // do not have to share one line at large font sizes.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (tag case final tag?)
                  Text(
                    tag,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                Text(stop.name, style: style),
                if (stop.platform != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: PlatformChip(
                      platform: stop.platform,
                      plannedPlatform: stop.plannedPlatform,
                      mode: mode,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
