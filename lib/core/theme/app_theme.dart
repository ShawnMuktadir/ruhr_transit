import 'package:flutter/material.dart';

/// Material 3 light and dark themes generated from one seed colour, so both
/// palettes stay consistent and meet M3 contrast guidelines.
abstract final class AppTheme {
  // Placeholder brand colour (a transit-style blue), not VRR's branding.
  static const Color _seed = Color(0xFF1565C0);

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
    );
  }
}
