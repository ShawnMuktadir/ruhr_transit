import 'package:flutter/material.dart';

/// A heading screen readers can jump to. Its own semantics node: without
/// `container`, Flutter merges the header flag into the surrounding area,
/// and TalkBack would read a whole form as one heading.
class Heading extends StatelessWidget {
  const Heading(this.text, {this.style, super.key});

  final String text;

  /// Defaults to `titleMedium`.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    container: true,
    child: Text(text, style: style ?? Theme.of(context).textTheme.titleMedium),
  );
}
