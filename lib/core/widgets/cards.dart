import 'package:flutter/material.dart';
import 'package:ruhr_transit/core/domain/transport_mode.dart';

/// Space around a card in a list, the same on every page.
const listCardMargin = EdgeInsets.symmetric(horizontal: 16, vertical: 4);

/// One row of a list as its own card: stops, departures, saved journeys.
/// Looks come from the app's card theme.
class ListCard extends StatelessWidget {
  const ListCard({
    required this.child,
    this.margin = listCardMargin,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final card = CardTheme.of(context);
    // Material rather than Card: Card always adds a semantics node (or
    // splits its children into nodes), which would move TalkBack actions
    // on the row (e.g. "Entfernen") off the node TalkBack focuses.
    return Padding(
      padding: margin,
      child: Material(
        color: card.color,
        shape: card.shape,
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}

/// A section of related rows in one card, divided by lines, like Android's
/// settings: e.g. "Darstellung" with its three choices.
class GroupCard extends StatelessWidget {
  const GroupCard({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    margin: listCardMargin,
    clipBehavior: Clip.antiAlias,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (index, child) in children.indexed) ...[
          if (index > 0) const Divider(height: 1, indent: 16, endIndent: 16),
          child,
        ],
      ],
    ),
  );
}

/// A card with a strip in the colour of a ride's transport mode on its
/// leading edge, for the rides of a trip.
class AccentCard extends StatelessWidget {
  const AccentCard({required this.mode, required this.child, super.key});

  /// Null when EFA sends a mode the app does not know: a neutral strip.
  final TransportMode? mode;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    margin: listCardMargin,
    clipBehavior: Clip.antiAlias,
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ColoredBox(
            color: switch (mode) {
              final mode? => modeAccent(mode, Theme.of(context).brightness),
              null => Theme.of(context).colorScheme.outline,
            },
            child: const SizedBox(width: 6),
          ),
          Expanded(child: child),
        ],
      ),
    ),
  );
}

/// The colour of a transport mode, as passengers know them from German
/// networks: red trains, green S-Bahn, blue U-Bahn, orange trams, purple
/// buses. Only for decoration next to the line badge, never for text.
Color modeAccent(TransportMode mode, Brightness brightness) {
  final dark = brightness == Brightness.dark;
  return switch (mode) {
    TransportMode.train =>
      dark ? const Color(0xFFEF9A9A) : const Color(0xFFC62828),
    TransportMode.suburbanTrain =>
      dark ? const Color(0xFFA5D6A7) : const Color(0xFF2E7D32),
    TransportMode.subway =>
      dark ? const Color(0xFF90CAF9) : const Color(0xFF1565C0),
    TransportMode.tram =>
      dark ? const Color(0xFFFFAB91) : const Color(0xFFD84315),
    TransportMode.bus =>
      dark ? const Color(0xFFCE93D8) : const Color(0xFF6A1B9A),
  };
}
