import 'package:flutter/material.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/features/trip_planner/domain/journey.dart';

/// Turn-by-turn directions of a walk, or of a change inside a station,
/// collapsed until the user asks for them: most people only need the
/// distance.
class WalkDirections extends StatefulWidget {
  const WalkDirections({
    required this.steps,
    this.paths = const [],
    this.initiallyExpanded = false,
    super.key,
  });

  /// For a walk the user asked for: the directions are the point.
  final bool initiallyExpanded;

  final List<WalkStep> steps;

  /// Lifts, escalators and stairs on the way, listed above the steps.
  final List<StationPath> paths;

  @override
  State<WalkDirections> createState() => _WalkDirectionsState();
}

class _WalkDirectionsState extends State<WalkDirections> {
  late var _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
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
                      _expanded
                          ? l10n.walkDirectionsHide
                          : l10n.walkDirectionsShow,
                      style: theme.textTheme.bodyMedium?.copyWith(color: color),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_expanded) ...[
          for (final path in widget.paths) _StationPathRow(path),
          for (final step in widget.steps) _StepRow(step),
        ],
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow(this.step);

  final WalkStep step;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final turn = turnLabel(l10n, step.turn);
    final name = step.name ?? l10n.walkStepFootpath;
    final meters = step.distanceMeters;
    // "Rechts abbiegen, Südring, 182 Meter" in one go.
    return MergeSemantics(
      child: Semantics(
        label: [
          turn,
          name,
          if (meters > 0) l10n.walkStepDistanceSpoken(meters),
        ].join(', '),
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                turnIcon(step.turn),
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: theme.textTheme.bodyMedium),
                    Text(
                      [
                        turn,
                        if (meters > 0) l10n.walkStepDistance(meters),
                      ].join(' · '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StationPathRow extends StatelessWidget {
  const _StationPathRow(this.path);

  final StationPath path;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final kind = switch (path.kind) {
      StationPathKind.elevator => l10n.stationPathElevator,
      StationPathKind.escalator => l10n.stationPathEscalator,
      StationPathKind.stairs => l10n.stationPathStairs,
      StationPathKind.other => l10n.stationPathOther,
    };
    final text = switch ((path.levelFrom, path.levelTo)) {
      (final from?, final to?) => l10n.stationPathLevels(kind, from, to),
      _ => kind,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            switch (path.kind) {
              StationPathKind.elevator => Icons.elevator_outlined,
              StationPathKind.escalator => Icons.escalator,
              StationPathKind.stairs => Icons.stairs_outlined,
              StationPathKind.other => Icons.swap_vert,
            },
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

String turnLabel(AppLocalizations l10n, WalkTurn turn) => switch (turn) {
  WalkTurn.straight => l10n.walkTurnStraight,
  WalkTurn.slightLeft => l10n.walkTurnSlightLeft,
  WalkTurn.left => l10n.walkTurnLeft,
  WalkTurn.sharpLeft => l10n.walkTurnSharpLeft,
  WalkTurn.slightRight => l10n.walkTurnSlightRight,
  WalkTurn.right => l10n.walkTurnRight,
  WalkTurn.sharpRight => l10n.walkTurnSharpRight,
  WalkTurn.uTurn => l10n.walkTurnUTurn,
  WalkTurn.board => l10n.walkTurnBoard,
  WalkTurn.alight => l10n.walkTurnAlight,
  WalkTurn.unknown => l10n.walkTurnUnknown,
};

IconData turnIcon(WalkTurn turn) => switch (turn) {
  WalkTurn.straight => Icons.straight,
  WalkTurn.slightLeft => Icons.turn_slight_left,
  WalkTurn.left => Icons.turn_left,
  WalkTurn.sharpLeft => Icons.turn_sharp_left,
  WalkTurn.slightRight => Icons.turn_slight_right,
  WalkTurn.right => Icons.turn_right,
  WalkTurn.sharpRight => Icons.turn_sharp_right,
  WalkTurn.uTurn => Icons.u_turn_left,
  WalkTurn.board => Icons.login,
  WalkTurn.alight => Icons.logout,
  WalkTurn.unknown => Icons.directions_walk,
};
