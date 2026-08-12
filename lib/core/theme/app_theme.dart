import 'package:flutter/material.dart';

/// Central place for the purple -> blue -> teal gradient used across the
/// welcome, auth, and section screens, plus the shared Material theme.
class AppGradients {
  static const List<Color> primary = [
    Color(0xFF7C5CFC),
    Color(0xFF4E8EF7),
    Color(0xFF5AD1D6),
  ];

  static const LinearGradient background = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: primary,
  );

  static const LinearGradient block = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF5B93F5), Color(0xFF4E8EF7)],
  );

  static const LinearGradient action = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFD9C7F5), Color(0xFFB9C7F0)],
  );
}

class AppTheme {
  static ThemeData get lightTheme {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6C63FF)),
      useMaterial3: true,
      scaffoldBackgroundColor: Colors.transparent,
    );
    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFB9C7F0),
          foregroundColor: Colors.black87,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(0.55),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  static ThemeData get darkTheme => ThemeData.dark(useMaterial3: true);
}
