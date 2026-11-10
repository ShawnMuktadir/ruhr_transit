import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// For parts of a page that also work without a cubit above them, e.g. in
/// tests of a single page.
extension OptionalProvider on BuildContext {
  /// [T] if an ancestor provides it, else null.
  T? maybeRead<T>() {
    try {
      return read<T>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  /// Like [maybeRead], and rebuilds when it changes.
  T? maybeWatch<T>() {
    try {
      return watch<T>();
    } on ProviderNotFoundException {
      return null;
    }
  }
}
