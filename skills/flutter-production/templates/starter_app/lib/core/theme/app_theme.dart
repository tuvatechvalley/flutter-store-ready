import 'package:material_ui/material_ui.dart';

/// Light and dark Material 3 themes from one seed color.
///
/// Contrast is handled by the generated ColorScheme; never hard-code text
/// colors on top of surfaces, always use `colorScheme.onX`.
abstract final class AppTheme {
  static const Color seed = Color(0xFF3F51B5);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: scheme,
      // 48x48 minimum tap targets on every platform (accessibility).
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size(64, 48)),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(),
    );
  }
}
