import 'package:flutter/material.dart';
import 'package:ruhr_transit/core/widgets/two_line_title.dart';

/// "Berlin, S+U Hauptbahnhof" over "→ Passau, Hauptbahnhof" in an app bar:
/// with towns, so both ends of a trip can be read.
abstract final class RouteTitle {
  static AppBar appBar(
    BuildContext context, {
    required String from,
    required String to,
    List<Widget> actions = const [],
  }) => TwoLineTitle.appBar(
    context,
    title: from,
    subtitle: '→ $to',
    semanticsLabel: '$from → $to',
    actions: actions,
  );
}
