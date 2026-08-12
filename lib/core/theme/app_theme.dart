import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Sahurada Color Tokens
  static const Color ink = Color(0xFF0F3B34);       // Deep Green
  static const Color ink2 = Color(0xFF123F38);
  static const Color text = Color(0xFF16221D);      // Dark Text
  static const Color paper = Color(0xFFEDEFEA);     // Background Gray-Green
  static const Color paperAlt = Color(0xFFE2E6DC);  // Lighter Gray-Green
  static const Color gold = Color(0xFFC98A2C);      // Accent Gold
  static const Color goldLight = Color(0xFFE9C489);
  static const Color clay = Color(0xFFB85C38);      // Clay Orange (Negative)
  static const Color sage = Color(0xFF7C9885);      // Muted Sage Green
  static const Color white = Color(0xFFFBFAF6);     // Card Background
  static const Color line = Color(0x1F16221D);      // Border line (rgba(22,34,29,0.12))

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: paper,
      primaryColor: ink,
      dividerColor: line,
      cardColor: white,
      textTheme: GoogleFonts.ibmPlexSansTextTheme().copyWith(
        bodyLarge: GoogleFonts.ibmPlexSans(color: text),
        bodyMedium: GoogleFonts.ibmPlexSans(color: text),
        titleLarge: GoogleFonts.newsreader(
          color: ink,
          fontWeight: FontWeight.w600,
          fontSize: 30,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: white,
        hintStyle: GoogleFonts.ibmPlexSans(color: sage, fontSize: 13),
        labelStyle: GoogleFonts.ibmPlexMono(color: sage, fontSize: 10, letterSpacing: 0.6),
        contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: line, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: line, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: gold, width: 1),
        ),
      ),
    );
  }

  static ThemeData get darkTheme => lightTheme; // Sahurada uses a light warm paper theme primarily
}
