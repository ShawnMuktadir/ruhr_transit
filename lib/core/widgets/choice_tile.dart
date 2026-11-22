import 'package:flutter/material.dart';

/// A row with several options, like a dropdown: shows the chosen one below
/// the title and opens a menu of all of them, the chosen one ticked.
///
/// A whole row rather than a dropdown squeezed into the trailing slot, so
/// long labels ("Predeterminado del sistema") and large text still fit, and
/// TalkBack reads title and value as one button.
class ChoiceTile<T> extends StatelessWidget {
  const ChoiceTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
    super.key,
  });

  final IconData icon;
  final String title;

  /// The chosen option; one of [options].
  final T value;

  /// Every option with its label, in menu order.
  final List<(T, String)> options;

  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final chosen = options.firstWhere((option) => option.$1 == value);
    return MenuAnchor(
      menuChildren: [
        for (final (option, label) in options)
          MenuItemButton(
            leadingIcon: option == value
                ? const Icon(Icons.check)
                : const SizedBox.square(dimension: 24),
            onPressed: () {
              if (option != value) onChanged(option);
            },
            child: Text(label),
          ),
      ],
      builder: (context, menu, _) => ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(chosen.$2),
        trailing: const Icon(Icons.arrow_drop_down),
        onTap: () => menu.isOpen ? menu.close() : menu.open(),
      ),
    );
  }
}
