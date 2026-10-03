import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/app_settings.dart';

class ReadingThemeConfig {
  final Color backgroundColor;
  final Color textColor;
  final Color secondaryTextColor;
  final Color accentColor;
  final Color dividerColor;
  final Color codeBackgroundColor;
  final Color cardBackgroundColor;

  const ReadingThemeConfig({
    required this.backgroundColor,
    required this.textColor,
    required this.secondaryTextColor,
    required this.accentColor,
    required this.dividerColor,
    required this.codeBackgroundColor,
    required this.cardBackgroundColor,
  });

  static ReadingThemeConfig getTheme(ReaderContrast contrast) {
    switch (contrast) {
      case ReaderContrast.mediumSepia:
        return const ReadingThemeConfig(
          backgroundColor: Color(0xFFFBF0D9), // Medium/Instapaper warm sepia
          textColor: Color(0xFF2C2416),
          secondaryTextColor: Color(0xFF6B583E),
          accentColor: Color(0xFF993300),
          dividerColor: Color(0xFFE2D5BA),
          codeBackgroundColor: Color(0xFFEFE4C9),
          cardBackgroundColor: Color(0xFFF4E7CC),
        );
      case ReaderContrast.cleanLight:
        return const ReadingThemeConfig(
          backgroundColor: Color(0xFFFFFFFF),
          textColor: Color(0xFF1E293B),
          secondaryTextColor: Color(0xFF64748B),
          accentColor: Color(0xFFE82427),
          dividerColor: Color(0xFFE2E8F0),
          codeBackgroundColor: Color(0xFFF1F5F9),
          cardBackgroundColor: Color(0xFFF8FAFC),
        );
      case ReaderContrast.softDark:
        return const ReadingThemeConfig(
          backgroundColor: Color(0xFF18181B), // Soft zinc dark
          textColor: Color(0xFFF4F4F5),
          secondaryTextColor: Color(0xFFA1A1AA),
          accentColor: Color(0xFFFF5252),
          dividerColor: Color(0xFF27272A),
          codeBackgroundColor: Color(0xFF27272A),
          cardBackgroundColor: Color(0xFF202024),
        );
      case ReaderContrast.oledBlack:
        return const ReadingThemeConfig(
          backgroundColor: Color(0xFF000000), // Pure AMOLED black
          textColor: Color(0xFFECECEC),
          secondaryTextColor: Color(0xFF888888),
          accentColor: Color(0xFFFF5252),
          dividerColor: Color(0xFF1A1A1A),
          codeBackgroundColor: Color(0xFF121212),
          cardBackgroundColor: Color(0xFF0C0C0C),
        );
      case ReaderContrast.forestMist:
        return const ReadingThemeConfig(
          backgroundColor: Color(0xFF0E1A17),
          textColor: Color(0xFFDCEFEA),
          secondaryTextColor: Color(0xFF80A69D),
          accentColor: Color(0xFF26A69A),
          dividerColor: Color(0xFF1B332E),
          codeBackgroundColor: Color(0xFF152622),
          cardBackgroundColor: Color(0xFF13221E),
        );
    }
  }

  static TextStyle getReadingTextStyle({
    required AppFontFamily fontFamily,
    required double fontScale,
    required double lineHeight,
    required Color color,
    double baseSize = 16.0,
    FontWeight fontWeight = FontWeight.normal,
  }) {
    final effectiveSize = baseSize * fontScale;

    switch (fontFamily) {
      case AppFontFamily.inter:
        return GoogleFonts.inter(
          fontSize: effectiveSize,
          height: lineHeight,
          color: color,
          fontWeight: fontWeight,
        );
      case AppFontFamily.plusJakarta:
        return GoogleFonts.plusJakartaSans(
          fontSize: effectiveSize,
          height: lineHeight,
          color: color,
          fontWeight: fontWeight,
        );
      case AppFontFamily.roboto:
        return GoogleFonts.roboto(
          fontSize: effectiveSize,
          height: lineHeight,
          color: color,
          fontWeight: fontWeight,
        );
      case AppFontFamily.literata:
        return GoogleFonts.literata(
          fontSize: effectiveSize,
          height: lineHeight,
          color: color,
          fontWeight: fontWeight,
        );
      case AppFontFamily.systemSans:
        return TextStyle(
          fontFamily: 'sans-serif',
          fontSize: effectiveSize,
          height: lineHeight,
          color: color,
          fontWeight: fontWeight,
        );
    }
  }
}
