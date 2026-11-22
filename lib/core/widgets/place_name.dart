import 'package:flutter/widgets.dart';

/// Names from VRR ("Bochum, Hbf", "Röhlinghauser Str.") are German, written
/// left to right. In the Arabic layout, right to left, their punctuation
/// would jump to the wrong end (".Röhlinghauser Str"). A Unicode isolate
/// (FSI … PDI) keeps each name in its own direction; it is invisible and
/// leaves Arabic text right to left.
extension PlaceName on String {
  /// This text, isolated when [context] lays out right to left; unchanged
  /// otherwise.
  String isolatedIn(BuildContext context) =>
      Directionality.of(context) == TextDirection.rtl
      ? '\u2068$this\u2069'
      : this;
}

/// The arrow between start and destination ("Bochum → Dortmund"), pointing
/// the way the text reads.
String routeArrow(BuildContext context) =>
    Directionality.of(context) == TextDirection.rtl ? '←' : '→';
