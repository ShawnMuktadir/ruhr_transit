import 'package:flutter/material.dart';

/// Shown behind a list row while it is swiped away to delete it.
class DismissBackground extends StatelessWidget {
  const DismissBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.errorContainer,
      child: Align(
        alignment: AlignmentDirectional.centerEnd,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(end: 24),
          child: Icon(Icons.delete_outline, color: colors.onErrorContainer),
        ),
      ),
    );
  }
}
