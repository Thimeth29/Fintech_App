import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppGradients {
  static const LinearGradient primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0D653E),
      Color(0xFF0B5232),
    ],
  );

  static const LinearGradient background = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFF7F9F7),
      Color(0xFFF7F9F7),
    ],
  );

  static const LinearGradient heroCard = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0D653E),
      Color(0xFF147A4D),
    ],
  );

  static const LinearGradient block = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0D653E),
      Color(0xFF0F6B43),
    ],
  );

  static const LinearGradient action = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0D653E),
      Color(0xFF16A34A),
    ],
  );

  static const LinearGradient gold = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFF3C06B),
      Color(0xFFD97706),
    ],
  );
}

class AppColors {
  static const Color primary = Color(0xFF0D653E);
  static const Color primaryDark = Color(0xFF08492C);
  static const Color bgLight = Color(0xFFF7F9F7);
  static const Color cardBg = Colors.white;
  static const Color mintBg = Color(0xFFEBF4EE);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color textDark = Color(0xFF1A1D1E);
  static const Color textMuted = Color(0xFF5A6578);
  static const Color goldAccent = Color(0xFFF3C06B);

  static const Color emerald = Color(0xFF0D653E);
  static const Color emeraldAccent = Color(0xFF16A34A);
  static const Color rose = Color(0xFFDC2626);
  static const Color roseAccent = Color(0xFFEF4444);
  static const Color roseDark = Color(0xFF9F1239);
}

class AppTheme {
  static const Color primaryColor = AppColors.primary;
  static const Color accentColor = AppColors.emerald;
  static const Color secondaryColor = AppColors.mintBg;

  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.outfitTextTheme(ThemeData.light().textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: accentColor,
        surface: Colors.white,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textDark,
      ),
      textTheme: baseTextTheme,
      scaffoldBackgroundColor: AppColors.bgLight,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textDark,
          backgroundColor: Colors.white,
          side: const BorderSide(color: AppColors.borderLight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          textStyle: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.borderLight),
        ),
      ),
    );
  }

  static ThemeData get darkTheme => lightTheme;
}

