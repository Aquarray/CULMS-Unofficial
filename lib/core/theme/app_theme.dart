import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/app_settings.dart';

class AppTheme {
  /// Default seed color (CUIMS brand signature crimson red).
  static const Color primaryRed = Color(0xFFE82427);
  static const Color defaultSeedColor = primaryRed;
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

  /// Builds a complete Material 3 ThemeData with ColorScheme.fromSeed
  static ThemeData buildTheme({
    required Brightness brightness,
    required AppFontFamily fontFamily,
    Color seedColor = defaultSeedColor,
    bool isAmoled = false,
  }) {
    final isDark = brightness == Brightness.dark;

    // 1. Generate Material 3 ColorScheme from Seed
    ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
      primary: seedColor,
    ).copyWith(
      onPrimary: Colors.white,
    );

    // Adjust dark / AMOLED surfaces for pure black contrast if requested
    if (isDark && isAmoled) {
      colorScheme = colorScheme.copyWith(
        surface: Colors.black,
        surfaceContainerLowest: Colors.black,
        surfaceContainerLow: const Color(0xFF0C0D0E),
        surfaceContainer: const Color(0xFF121417),
        surfaceContainerHigh: const Color(0xFF1B1E22),
        surfaceContainerHighest: const Color(0xFF24282E),
      );
    }

    final base = ThemeData(brightness: brightness, useMaterial3: true);
    final textTheme = _buildTextTheme(fontFamily, base.textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      primaryColor: seedColor,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isDark
          ? (isAmoled ? Colors.black : const Color(0xFF111315))
          : const Color(0xFFF8FAFC),
      textTheme: textTheme,

      // Icon Theme: Bold, clean iconography with dedicated weights
      iconTheme: IconThemeData(
        color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
        size: 22,
      ),
      primaryIconTheme: IconThemeData(
        color: colorScheme.primary,
        size: 22,
      ),
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (BuildContext context) => const Icon(Icons.arrow_back_rounded, size: 22),
        closeButtonIconBuilder: (BuildContext context) => const Icon(Icons.close_rounded, size: 22),
        drawerButtonIconBuilder: (BuildContext context) => const Icon(Icons.menu_rounded, size: 22),
      ),

      // 2. NavigationBar Theme (Material 3 standard for navigation bars)
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 1,
        backgroundColor: isDark
            ? (isAmoled ? Colors.black : const Color(0xFF181B1F))
            : Colors.white,
        indicatorColor: colorScheme.primaryContainer,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colorScheme.onPrimaryContainer, size: 24);
          }
          return IconThemeData(color: colorScheme.onSurfaceVariant, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
          );
        }),
      ),

      // 3. FilledButton Theme (Standard M3 Primary Action)
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      // 4. OutlinedButton & ElevatedButton Themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),

      // 5. SegmentedButton Theme
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ),

      // 6. Card Theme
      cardTheme: CardThemeData(
        color: isDark
            ? (isAmoled ? const Color(0xFF0F0F0F) : const Color(0xFF1B1E22))
            : Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark
                ? (isAmoled ? const Color(0xFF222222) : const Color(0xFF2A2E35))
                : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),

      // 7. AppBar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: isDark
            ? (isAmoled ? Colors.black : const Color(0xFF111315))
            : Colors.white,
        foregroundColor: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
      ),

      // 8. Input Decoration Theme (M3 Outlined / Filled Inputs)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? (isAmoled ? const Color(0xFF141414) : const Color(0xFF1D2025))
            : const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      // 9. Dialog & BottomSheet Themes
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? const Color(0xFF1E2227) : Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? const Color(0xFF1E2227) : Colors.white,
        elevation: 2,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      // 10. Switch, Chip & SnackBar Themes
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white; // Crisp, clearly defined white circle when active
          }
          return isDark ? const Color(0xFFE2E8F0) : const Color(0xFF64748B); // Distinct visible circle when inactive
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return isDark ? const Color(0xFF2A2E35) : const Color(0xFFCBD5E1);
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.transparent;
          }
          return isDark ? const Color(0xFF3F444E) : const Color(0xFF94A3B8);
        }),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: DividerThemeData(
        color: isDark
            ? (isAmoled ? const Color(0xFF222222) : const Color(0xFF2A2E35))
            : const Color(0xFFE2E8F0),
        thickness: 1,
      ),
    );
  }

  static ThemeData lightTheme(AppFontFamily fontFamily, {Color seedColor = defaultSeedColor}) =>
      buildTheme(brightness: Brightness.light, fontFamily: fontFamily, seedColor: seedColor);

  static ThemeData darkTheme(AppFontFamily fontFamily, {Color seedColor = defaultSeedColor, bool isAmoled = false}) =>
      buildTheme(brightness: Brightness.dark, fontFamily: fontFamily, seedColor: seedColor, isAmoled: isAmoled);
}
