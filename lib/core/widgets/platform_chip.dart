import 'package:flutter/material.dart';
import 'package:ruhr_transit/core/domain/transport_mode.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';

/// A word of three letters or more, as in EFA's "Gleis 2 (U)",
/// "U-Bahn Gleis 2", "Steig 1" or "Bus". Single letters ("7 A-D") are part
/// of a bare platform number.
final _namesItself = RegExp('[A-Za-zÄÖÜäöüß]{3}');

/// EFA's German word in front of the number, as in "Gleis 2 (U)" or
/// "Steig 1": translated like a bare number, so English does not show
/// "Gleis".
final _germanWord = RegExp(r'^(Gleis|Steig)\s+(\S.*)$');

/// The number without EFA's German word, for "(was 1 (U))".
String _number(String platform) =>
    _germanWord.firstMatch(platform.trim())?.group(2) ?? platform.trim();

/// The platform as it should be shown: "Gleis 5" / "Platform 5" for a bare
/// number, "Steig 03" / "Bay 03" for a bus, "Gleis 2 (U)" / "Platform 2 (U)"
/// for EFA's own German word, and EFA's text unchanged when it otherwise
/// says what it is ("U-Bahn Gleis 2", "Bus"). Null when there is no
/// platform.
String? platformLabel(
  AppLocalizations l10n,
  String? platform, {
  TransportMode? mode,
}) {
  final value = platform?.trim();
  if (value == null || value.isEmpty) return null;
  if (_germanWord.firstMatch(value) case final match?) {
    return match.group(1) == 'Steig'
        ? l10n.platformLabelBus(match.group(2)!)
        : l10n.platformLabel(match.group(2)!);
  }
  if (_namesItself.hasMatch(value)) return value;
  return mode == TransportMode.bus
      ? l10n.platformLabelBus(value)
      : l10n.platformLabel(value);
}

/// The platform as text, with the timetable's when it changed, e.g.
/// "Gleis 4 (statt 3)": the old one tells where not to wait. Null when
/// there is no platform.
String? platformText(
  AppLocalizations l10n,
  String? platform, {
  String? plannedPlatform,
  TransportMode? mode,
}) {
  final label = platformLabel(l10n, platform, mode: mode);
  if (label == null) return null;
  return _isChanged(platform, plannedPlatform)
      ? l10n.platformChangedHint(label, _number(plannedPlatform!))
      : label;
}

/// What a screen reader says for the platform, e.g. "Gleis 5" or
/// "Gleiswechsel: Gleis 4 statt 3". Null when there is no platform.
String? platformSpokenLabel(
  AppLocalizations l10n,
  String? platform, {
  String? plannedPlatform,
  TransportMode? mode,
}) {
  final label = platformLabel(l10n, platform, mode: mode);
  if (label == null) return null;
  return _isChanged(platform, plannedPlatform)
      ? l10n.departurePlatformChanged(label, _number(plannedPlatform!))
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
    final text = platformText(
      l10n,
      platform,
      plannedPlatform: plannedPlatform,
      mode: mode,
    );
    if (text == null) return const SizedBox.shrink();

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
        text,
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
