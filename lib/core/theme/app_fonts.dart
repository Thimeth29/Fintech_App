import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// App typography: Poppins for headings, Inter for body text and numbers.
///
/// Every style turns on tabular figures, so digits share one width and
/// currency amounts line up in columns and don't jiggle as they update.
class AppFonts {
  AppFonts._();

  static const List<FontFeature> tabularFigures = [FontFeature.tabularFigures()];

  /// Text at least this large *and* this heavy is treated as a heading.
  static const double _headingMinSize = 18;
  static const FontWeight _headingMinWeight = FontWeight.w600;

  /// Poppins — titles, section headers, big hero numbers.
  static TextStyle heading({
    TextStyle? textStyle,
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? height,
    List<Shadow>? shadows,
    TextDecoration? decoration,
  }) =>
      GoogleFonts.poppins(
        textStyle: textStyle,
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontStyle: fontStyle,
        letterSpacing: letterSpacing,
        height: height,
        shadows: shadows,
        decoration: decoration,
        fontFeatures: tabularFigures,
      );

  /// Inter — body copy, labels, amounts.
  static TextStyle body({
    TextStyle? textStyle,
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? height,
    List<Shadow>? shadows,
    TextDecoration? decoration,
  }) =>
      GoogleFonts.inter(
        textStyle: textStyle,
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontStyle: fontStyle,
        letterSpacing: letterSpacing,
        height: height,
        shadows: shadows,
        decoration: decoration,
        fontFeatures: tabularFigures,
      );

  /// General-purpose style: picks [heading] for large bold text and [body]
  /// for everything else, so call sites only state size and weight.
  static TextStyle text({
    TextStyle? textStyle,
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? height,
    List<Shadow>? shadows,
    TextDecoration? decoration,
  }) {
    final isHeading = (fontSize ?? 0) >= _headingMinSize &&
        (fontWeight ?? FontWeight.w400).value >= _headingMinWeight.value;
    return (isHeading ? heading : body)(
      textStyle: textStyle,
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      height: height,
      shadows: shadows,
      decoration: decoration,
    );
  }

  /// [base] with Poppins on display / headline / title styles and Inter on
  /// body / label styles. Sizes, weights and colors from [base] are kept.
  static TextTheme textTheme(TextTheme base) {
    final poppins = GoogleFonts.poppinsTextTheme(base);
    final inter = GoogleFonts.interTextTheme(base);
    TextStyle? tab(TextStyle? s) => s?.copyWith(fontFeatures: tabularFigures);
    return TextTheme(
      displayLarge: tab(poppins.displayLarge),
      displayMedium: tab(poppins.displayMedium),
      displaySmall: tab(poppins.displaySmall),
      headlineLarge: tab(poppins.headlineLarge),
      headlineMedium: tab(poppins.headlineMedium),
      headlineSmall: tab(poppins.headlineSmall),
      titleLarge: tab(poppins.titleLarge),
      titleMedium: tab(poppins.titleMedium),
      titleSmall: tab(poppins.titleSmall),
      bodyLarge: tab(inter.bodyLarge),
      bodyMedium: tab(inter.bodyMedium),
      bodySmall: tab(inter.bodySmall),
      labelLarge: tab(inter.labelLarge),
      labelMedium: tab(inter.labelMedium),
      labelSmall: tab(inter.labelSmall),
    );
  }
}
