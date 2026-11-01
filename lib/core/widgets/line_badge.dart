import 'package:flutter/material.dart';
import 'package:ruhr_transit/core/domain/transport_mode.dart';
import 'package:ruhr_transit/core/widgets/transport_mode_icon.dart';

/// A line as a badge with its transport icon, e.g. [train icon] RE16.
class LineBadge extends StatelessWidget {
  const LineBadge(this.line, {this.mode, this.minWidth = 64, super.key});

  final String line;
  final TransportMode? mode;

  /// Keeps badges in a column the same width; smaller in a row of badges.
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      constraints: BoxConstraints(minWidth: minWidth),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (mode case final mode?) ...[
            TransportModeIcon(mode, size: 16, color: colors.onPrimaryContainer),
            const SizedBox(width: 4),
          ],
          Text(
            line,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colors.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
