import 'package:flutter/material.dart';

/// A centred text with an optional button below, for idle, empty and error
/// states.
///
/// Scrollable, so a long message with buttons still fits at large font
/// sizes, and pull-to-refresh works around it.
class CenteredMessage extends StatelessWidget {
  const CenteredMessage(this.text, {this.action, super.key});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          // Centred while it fits, scrolling once it does not.
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    text,
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  if (action case final action?) ...[
                    const SizedBox(height: 16),
                    action,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
