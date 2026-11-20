import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/widgets/two_line_title.dart';

/// The title of the departure board of [fullName] ("Bochum, Hbf"): the
/// stop's name over its town.
Finder findBoardTitle(String fullName) => find.byWidgetPredicate(
  (widget) => widget is TwoLineTitle && widget.semanticsLabel == fullName,
);
