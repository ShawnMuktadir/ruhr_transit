import 'package:flutter/material.dart';
import 'package:ruhr_transit/core/widgets/place_name.dart';
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
    title: from.isolatedIn(context),
    subtitle: '${routeArrow(context)} ${to.isolatedIn(context)}',
    semanticsLabel: '$from → $to',
    actions: actions,
  );
}
