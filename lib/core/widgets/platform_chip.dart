import 'package:flutter/material.dart';
import 'package:ruhr_transit/core/domain/transport_mode.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';

/// A word of three letters or more, as in EFA's "Gleis 2 (U)",
/// "U-Bahn Gleis 2", "Steig 1" or "Bus". Single letters ("7 A-D") are part
/// of a bare platform number.
final _namesItself = RegExp('[A-Za-zÄÖÜäöüß]{3}');

/// The platform as it should be shown: "Gleis 5" / "Platform 5" for a bare
/// number, "Steig 03" / "Bay 03" for a bus, and EFA's text unchanged when it
/// already says what it is. Null when there is no platform.
String? platformLabel(
  AppLocalizations l10n,
  String? platform, {
  TransportMode? mode,
}) {
  final value = platform?.trim();
  if (value == null || value.isEmpty) return null;
  if (_namesItself.hasMatch(value)) return value;
  return mode == TransportMode.bus
      ? l10n.platformLabelBus(value)
      : l10n.platformLabel(value);
}

/// What a screen reader says for the platform, e.g. "Gleis 5" or
/// "Gleiswechsel auf Gleis 2". Null when there is no platform.
String? platformSpokenLabel(
  AppLocalizations l10n,
  String? platform, {
  String? plannedPlatform,
  TransportMode? mode,
}) {
  final label = platformLabel(l10n, platform, mode: mode);
  if (label == null) return null;
  return _isChanged(platform, plannedPlatform)
      ? l10n.departurePlatformChanged(label)
      : label;
}

bool _isChanged(String? platform, String? plannedPlatform) {
  final planned = plannedPlatform?.trim();
  return planned != null && planned.isNotEmpty && planned != platform?.trim();
}

/// The platform as a filled, bold badge, so it is easy to spot. A platform
/// that differs from the timetable is highlighted in the error colours and
/// marked as changed. Shows nothing without a platform.
class PlatformChip extends StatelessWidget {
  const PlatformChip({
    required this.platform,
    this.plannedPlatform,
    this.mode,
    super.key,
  });

  /// Where the vehicle actually stops, as EFA sends it.
  final String? platform;

  /// From the timetable; only used to detect a change.
  final String? plannedPlatform;

  /// Buses get "Steig"/"Bay" instead of "Gleis"/"Platform".
  final TransportMode? mode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = platformLabel(l10n, platform, mode: mode);
    if (label == null) return const SizedBox.shrink();

    final colors = Theme.of(context).colorScheme;
    final changed = _isChanged(platform, plannedPlatform);
    final foreground = changed
        ? colors.onErrorContainer
        : colors.onSecondaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: changed ? colors.errorContainer : colors.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        changed ? l10n.platformChangedHint(label) : label,
        semanticsLabel: platformSpokenLabel(
          l10n,
          platform,
          plannedPlatform: plannedPlatform,
          mode: mode,
        ),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: foreground,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
