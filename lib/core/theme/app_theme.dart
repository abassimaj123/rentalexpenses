import 'package:flutter/material.dart';
import 'package:calcwise_core/calcwise_core.dart';

class AppTheme {
  AppTheme._();

  static const Color primary      = Color(0xFF16A34A); // Green 600
  static const Color accent       = Color(0xFFF59E0B); // Amber 500
  static const Color background   = Color(0xFFF8FAFC);
  static const Color cardWhite    = Colors.white;
  static const Color success      = Color(0xFF34C759);
  static const Color warning      = Color(0xFFFFA500);
  static const Color labelGray    = Color(0xFF64748B);
  static const Color divider      = Color(0xFFE2E8F0);
  static const Color inputFill    = Color(0xFFF1F5F9);
  static const Color chartPurple  = Color(0xFF9C27B0);
  static const Color chartTeal    = Color(0xFF009688);
  static const Color surfaceTint  = Color(0xFFECFDF5); // green-50
  static const Color dangerRed    = Color(0xFFDC2626);

  // Category palette — breakdown charts and expense lists
  static const List<Color> categoryPalette = [
    Color(0xFF16A34A), // green
    Color(0xFF2563EB), // blue
    Color(0xFFC8102E), // red
    Color(0xFFD97706), // amber
    Color(0xFF7C3AED), // violet
    Color(0xFF0891B2), // cyan
    Color(0xFFDB2777), // pink
    Color(0xFF65A30D), // lime
    Color(0xFF9333EA), // purple
    Color(0xFF0D9488), // teal
  ];

  static ThemeData get theme => CalcwiseThemeFactory.buildLight(primary: primary, accent: accent);
  static ThemeData get dark  => CalcwiseThemeFactory.buildDark(primary: primary, accent: accent);

  static LinearGradient get primaryGradient => LinearGradient(
    colors: [primary, Color.lerp(primary, Colors.black, 0.15)!],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
