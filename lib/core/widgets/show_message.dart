import 'package:flutter/material.dart';

/// Shows [text] in a snack bar, replacing the one shown, so quick actions
/// never queue up old messages.
///
/// On the messenger rather than a `BuildContext`, so it can be read before
/// an `await` and used after it.
extension ShowMessage on ScaffoldMessengerState {
  /// How long a message stays, and one with an [action] (e.g. Undo), which
  /// needs time to reach the button.
  static const duration = Duration(seconds: 4);
  static const durationWithAction = Duration(seconds: 8);

  void showMessage(String text, {SnackBarAction? action}) {
    // Flutter keeps snack bars with an action until dismissed. They close
    // by themselves here, except with TalkBack or VoiceOver on: finding the
    // button by swiping takes longer.
    final screenReader =
        MediaQuery.maybeAccessibleNavigationOf(context) ?? false;
    this
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          action: action,
          duration: action == null ? duration : durationWithAction,
          persist: action != null && screenReader,
        ),
      );
  }
}
