import 'package:flutter/material.dart';

/// Shows [text] in a snack bar, replacing the one shown, so quick actions
/// never queue up old messages.
///
/// On the messenger rather than a `BuildContext`, so it can be read before
/// an `await` and used after it.
extension ShowMessage on ScaffoldMessengerState {
  void showMessage(String text, {SnackBarAction? action}) => this
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), action: action));
}
