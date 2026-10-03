import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/app_settings.dart';

/// Minimal & Editorial Design System for CUIMS
/// 
/// Palette:
/// - Light: Warm Alabaster (#FBFBF9), Pure Paper (#FFFFFF), Hairline Rule (#E8E6DF), Deep Sumi Ink (#181816)
/// - Dark: Warm Obsidian (#131312), Espresso Slate (#1B1B19), Dark Hairline (#2E2E2A), Newsprint White (#F4F3EE)
/// - Accent: Tuscan Crimson / Academic Vermilion (#9B2226 / #B91C1C)
///
/// Typography:
/// - Editorial Serif Headlines: Literata / Newsreader
/// - Precision UI Sans: Plus Jakarta Sans / Inter
///
/// Architecture:
/// - Corner Radius: 6px–10px (tailored, print-like cardstock)
/// - Elevation: 0 (flat hairline separation, no floating shadows)
class AppTheme {
  // Editorial Color Tokens
  static const Color editorialCarmine = Color(0xFF9B2226); // Academic Tuscan Carmine
  static const Color defaultSeedColor = editorialCarmine;
  static const Color primaryRed = editorialCarmine;
  static const Color accentIndigo = Color(0xFF4F46E5);

  // Light Palette
  static const Color lightCanvas = Color(0xFFFBFBF9); // Warm Alabaster / Milk paper
  static const Color lightSurface = Color(0xFFFFFFFF); // Clean book card
  static const Color lightSurfaceMuted = Color(0xFFF4F3EE); // Gallery Chalk
  static const Color lightBorder = Color(0xFFE8E6DF); // Delicate hairline rule
  static const Color lightInkPrimary = Color(0xFF181816); // Deep Sumi Ink
  static const Color lightInkSecondary = Color(0xFF4C4A45); // Charcoal Slate
  static const Color lightInkMuted = Color(0xFF7C7A73); // Warm Stone

  // Dark Palette
  static const Color darkCanvas = Color(0xFF131312); // Warm Obsidian
  static const Color darkSurface = Color(0xFF1B1B19); // Espresso Charcoal
  static const Color darkSurfaceMuted = Color(0xFF232321); // Slate Muted
  static const Color darkBorder = Color(0xFF2E2E2A); // Muted Dark Rule
  static const Color darkInkPrimary = Color(0xFFF4F3EE); // Newsprint White
  static const Color darkInkSecondary = Color(0xFFBEBCB4); // Warm Gray
  static const Color darkInkMuted = Color(0xFF7A7872); // Muted Stone

  /// Editorial Typography Pairing:
  /// Serif Headings (Literata) + Precision UI Body (Inter / Plus Jakarta Sans)
  static TextTheme _buildEditorialTextTheme(AppFontFamily fontFamily, TextTheme base, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final primaryColor = isDark ? darkInkPrimary : lightInkPrimary;
    final secondaryColor = isDark ? darkInkSecondary : lightInkSecondary;

    // 1. Base UI Sans
    TextTheme sansTheme;
    switch (fontFamily) {
      case AppFontFamily.inter:
        sansTheme = GoogleFonts.interTextTheme(base);
        break;
      case AppFontFamily.plusJakarta:
        sansTheme = GoogleFonts.plusJakartaSansTextTheme(base);
        break;
      case AppFontFamily.roboto:
        sansTheme = GoogleFonts.robotoTextTheme(base);
        break;
      case AppFontFamily.literata:
        sansTheme = GoogleFonts.literataTextTheme(base);
        break;
      case AppFontFamily.systemSans:
        sansTheme = base.apply(fontFamily: 'sans-serif');
        break;
    }

    // 2. Editorial Serif Headings (Literata - Google Books & modern prestige editorial standard)
    return sansTheme.copyWith(
      displayLarge: GoogleFonts.literata(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: primaryColor,
      ),
      displayMedium: GoogleFonts.literata(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: primaryColor,
      ),
      displaySmall: GoogleFonts.literata(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: primaryColor,
      ),
      headlineLarge: GoogleFonts.literata(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: primaryColor,
      ),
      headlineMedium: GoogleFonts.literata(
        fontSize: 19,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: primaryColor,
      ),
      headlineSmall: GoogleFonts.literata(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        color: primaryColor,
      ),
      titleLarge: GoogleFonts.literata(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: primaryColor,
      ),
      titleMedium: sansTheme.titleMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: primaryColor,
        letterSpacing: 0.1,
      ),
      titleSmall: sansTheme.titleSmall?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: secondaryColor,
        letterSpacing: 0.1,
      ),
      bodyLarge: sansTheme.bodyLarge?.copyWith(
        fontSize: 15,
        color: primaryColor,
        height: 1.5,
      ),
      bodyMedium: sansTheme.bodyMedium?.copyWith(
        fontSize: 13.5,
        color: secondaryColor,
        height: 1.45,
      ),
      bodySmall: sansTheme.bodySmall?.copyWith(
        fontSize: 12,
        color: isDark ? darkInkMuted : lightInkMuted,
        height: 1.4,
      ),
      labelLarge: sansTheme.labelLarge?.copyWith(
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
      labelMedium: sansTheme.labelMedium?.copyWith(
        fontSize: 11.5,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
      ),
      labelSmall: sansTheme.labelSmall?.copyWith(
        fontSize: 10.5,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.3,
      ),
    );
  }

  /// Builds the complete Minimal & Editorial ThemeData
  static ThemeData buildTheme({
    required Brightness brightness,
    required AppFontFamily fontFamily,
    Color seedColor = defaultSeedColor,
    bool isAmoled = false,
  }) {
    final isDark = brightness == Brightness.dark;

    // Editorial Surfaces
    final canvasColor = isDark
        ? (isAmoled ? Colors.black : darkCanvas)
        : lightCanvas;
    final cardColor = isDark
        ? (isAmoled ? const Color(0xFF0A0A0A) : darkSurface)
        : lightSurface;
    final surfaceMuted = isDark
        ? (isAmoled ? const Color(0xFF141414) : darkSurfaceMuted)
        : lightSurfaceMuted;
    final borderColor = isDark
        ? (isAmoled ? const Color(0xFF202020) : darkBorder)
        : lightBorder;

    // Refined Editorial ColorScheme
    final baseColorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
      surface: cardColor,
    );

    ColorScheme colorScheme = baseColorScheme.copyWith(
      primary: seedColor,
      onPrimary: Colors.white,
      outline: borderColor,
      outlineVariant: borderColor,
      surfaceContainerLowest: isDark ? (isAmoled ? Colors.black : const Color(0xFF0E0E0D)) : const Color(0xFFFFFFFF),
      surfaceContainerLow: isDark ? darkSurface : const Color(0xFFFAFAF7),
      surfaceContainer: cardColor,
      surfaceContainerHigh: surfaceMuted,
      surfaceContainerHighest: isDark ? const Color(0xFF2C2C29) : const Color(0xFFEAE8E2),
    );

    final base = ThemeData(brightness: brightness, useMaterial3: true);
    final textTheme = _buildEditorialTextTheme(fontFamily, base.textTheme, brightness);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      primaryColor: seedColor,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: canvasColor,
      textTheme: textTheme,

      // Editorial Icon Theme
      iconTheme: IconThemeData(
        color: isDark ? darkInkPrimary : lightInkPrimary,
        size: 20,
      ),
      primaryIconTheme: IconThemeData(
        color: colorScheme.primary,
        size: 20,
      ),
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (BuildContext context) => const Icon(Icons.arrow_back_rounded, size: 20),
        closeButtonIconBuilder: (BuildContext context) => const Icon(Icons.close_rounded, size: 20),
        drawerButtonIconBuilder: (BuildContext context) => const Icon(Icons.menu_rounded, size: 20),
      ),

      // NavigationBar: Minimal Flush Bottom Nav
      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        elevation: 0,
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        indicatorColor: isDark
            ? colorScheme.primary.withValues(alpha: 0.18)
            : colorScheme.primary.withValues(alpha: 0.08),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colorScheme.primary, size: 22);
          }
          return IconThemeData(
            color: isDark ? darkInkMuted : lightInkMuted,
            size: 20,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? colorScheme.primary : (isDark ? darkInkMuted : lightInkMuted),
            letterSpacing: 0.2,
          );
        }),
      ),

      // FilledButton: Architectural, Minimal 8px Radius, High Contrast
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 46),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
          textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, letterSpacing: 0.2),
        ),
      ),

      // Outlined & Elevated Buttons: Hairline Crisp Borders
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: surfaceMuted,
          foregroundColor: isDark ? darkInkPrimary : lightInkPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: borderColor, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          side: BorderSide(color: borderColor, width: 1),
          foregroundColor: isDark ? darkInkPrimary : lightInkPrimary,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),

      // Segmented Button Theme
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          side: WidgetStatePropertyAll(BorderSide(color: borderColor, width: 1)),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
        ),
      ),

      // Editorial Card Theme: Flat Paper with 10px Radius and 1px Hairline Rule
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: borderColor, width: 1),
        ),
      ),

      // AppBar Theme: Paper Canvas, Zero Elevation, Refined Serif Title
      appBarTheme: AppBarTheme(
        backgroundColor: canvasColor,
        foregroundColor: isDark ? darkInkPrimary : lightInkPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: isDark ? darkInkPrimary : lightInkPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 18,
          letterSpacing: -0.3,
        ),
      ),

      // Input Decoration Theme: 8px Radius, Soft Chalk Fill, Subtle Hairline
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: borderColor, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: borderColor, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        hintStyle: TextStyle(
          color: isDark ? darkInkMuted : lightInkMuted,
          fontSize: 13,
        ),
      ),

      // Dialog & BottomSheet Themes: Tailored 12px-16px Radius
      dialogTheme: DialogThemeData(
        backgroundColor: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: borderColor, width: 1),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cardColor,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: isDark ? darkInkMuted : lightInkMuted,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),

      // Switch Theme: High-Contrast, Tactile M3 Switch with Rich Saturated Track
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return isDark ? const Color(0xFF8C8A82) : const Color(0xFF75746E);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return isDark ? const Color(0xFF262624) : const Color(0xFFE2E0D8);
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.transparent;
          }
          return isDark ? const Color(0xFF5A5852) : const Color(0xFF9E9C94);
        }),
        trackOutlineWidth: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected) ? 0.0 : 1.5;
        }),
        thumbIcon: WidgetStateProperty.resolveWith<Icon?>((states) {
          if (states.contains(WidgetState.selected)) {
            return Icon(
              Icons.check_rounded,
              size: 14,
              color: colorScheme.primary,
            );
          }
          return null;
        }),
      ),

      // Chip Theme: Subtle 6px Radius
      chipTheme: ChipThemeData(
        backgroundColor: surfaceMuted,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: BorderSide(color: borderColor, width: 1),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: isDark ? darkInkPrimary : lightInkPrimary,
        ),
      ),

      // SnackBar Theme: Clean, minimal floating pill
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFF242422) : const Color(0xFF1E1E1C),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: isDark ? const Color(0xFF383834) : Colors.transparent),
        ),
      ),

      // Divider Theme: Crisp 1px Hairline Rule
      dividerTheme: DividerThemeData(
        color: borderColor,
        thickness: 1,
        space: 1,
      ),
    );
  }

  static ThemeData lightTheme(AppFontFamily fontFamily, {Color seedColor = defaultSeedColor}) =>
      buildTheme(brightness: Brightness.light, fontFamily: fontFamily, seedColor: seedColor);

  static ThemeData darkTheme(AppFontFamily fontFamily, {Color seedColor = defaultSeedColor, bool isAmoled = false}) =>
      buildTheme(brightness: Brightness.dark, fontFamily: fontFamily, seedColor: seedColor, isAmoled: isAmoled);
}
