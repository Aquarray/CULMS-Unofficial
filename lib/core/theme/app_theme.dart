import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/app_settings.dart';

class AppTheme {
  static const Color primaryRed = Color(0xFFE82427); // CUIMS red signature accent
  static const Color accentIndigo = Color(0xFF6366F1);

  static TextTheme _buildTextTheme(AppFontFamily fontFamily, TextTheme base) {
    switch (fontFamily) {
      case AppFontFamily.inter:
        return GoogleFonts.interTextTheme(base);
      case AppFontFamily.plusJakarta:
        return GoogleFonts.plusJakartaSansTextTheme(base);
      case AppFontFamily.roboto:
        return GoogleFonts.robotoTextTheme(base);
      case AppFontFamily.literata:
        return GoogleFonts.literataTextTheme(base);
      case AppFontFamily.systemSans:
        return base.apply(fontFamily: 'sans-serif');
    }
  }

  static ThemeData lightTheme(AppFontFamily fontFamily) {
    final base = ThemeData.light(useMaterial3: true);
    final textTheme = _buildTextTheme(fontFamily, base.textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryRed,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryRed,
        brightness: Brightness.light,
        surface: const Color(0xFFF9FAFB),
        primary: primaryRed,
      ),
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: const Color(0xFF1E293B),
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
      ),
      textTheme: textTheme,
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE2E8F0),
        thickness: 1,
      ),
    );
  }

  static ThemeData darkTheme(AppFontFamily fontFamily, {bool isAmoled = false}) {
    final base = ThemeData.dark(useMaterial3: true);
    final textTheme = _buildTextTheme(fontFamily, base.textTheme);
    final bgColor = isAmoled ? Colors.black : const Color(0xFF121417);
    final cardColor = isAmoled ? const Color(0xFF0F0F0F) : const Color(0xFF1B1E22);
    final borderColor = isAmoled ? const Color(0xFF222222) : const Color(0xFF2A2E35);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryRed,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryRed,
        brightness: Brightness.dark,
        surface: cardColor,
        primary: primaryRed,
      ),
      scaffoldBackgroundColor: bgColor,
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor, width: 1),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bgColor,
        foregroundColor: const Color(0xFFF1F5F9),
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: const Color(0xFFF1F5F9),
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
      ),
      textTheme: textTheme,
      dividerTheme: DividerThemeData(
        color: borderColor,
        thickness: 1,
      ),
    );
  }
}
