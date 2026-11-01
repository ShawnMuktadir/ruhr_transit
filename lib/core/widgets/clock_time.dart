import 'package:flutter/material.dart';

/// [time] is UTC, like everything EFA sends; shown in the device's time zone
/// and 12/24-hour setting, e.g. `17:13` or `5:13 PM`.
String formatClockTime(BuildContext context, DateTime time) {
  return MaterialLocalizations.of(context).formatTimeOfDay(
    TimeOfDay.fromDateTime(time.toLocal()),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
}
