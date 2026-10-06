import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Single source of truth for the app's brand color — everything else
/// (the Material ColorScheme, the gradient backdrop, and the auth flow's
/// accent color) derives from this so the whole app reads as one product.
const Color _seed = Color(0xFF3D5AFE);

/// The gradient backdrop used across the welcome, auth, and section
/// screens, plus the shared Material theme. Both derived from [_seed] so
/// they always stay in the same family.
class AppGradients {
  static const List<Color> primary = [
    Color(0xFF5B4BDB), // indigo-violet
    Color(0xFF3D5AFE), // brand blue
    Color(0xFF2FB6C4), // teal
  ];

  static const LinearGradient background = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: primary,
  );

  static const LinearGradient block = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4F63F2), Color(0xFF3D5AFE)],
  );

  static const LinearGradient action = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2FB6C4), Color(0xFF3DA9F2)],
  );
}

class AppTheme {
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.light,
    );
    final textTheme = GoogleFonts.rubikTextTheme();

    final base = ThemeData(
      colorScheme: colorScheme,
      textTheme: textTheme,
      useMaterial3: true,
      scaffoldBackgroundColor: Colors.transparent,
      splashFactory: InkRipple.splashFactory,
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          textStyle: textTheme.labelLarge?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 2,
      ),
      cardTheme: CardThemeData(
        color: Colors.white.withValues(alpha: 0.9),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.7)),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: Colors.white.withValues(alpha: 0.75),
        labelStyle: textTheme.labelMedium,
        shape: StadiumBorder(
            side:
                BorderSide(color: colorScheme.primary.withValues(alpha: 0.25))),
      ),
      dividerTheme: const DividerThemeData(space: 32, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.7),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  static ThemeData get darkTheme => ThemeData.dark(useMaterial3: true);
}
