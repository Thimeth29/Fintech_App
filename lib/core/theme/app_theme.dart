import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../platform/app_platform.dart';
import 'app_fonts.dart';

class AppGradients {
  static const LinearGradient primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF2563EB),
      Color(0xFF1E3A8A),
    ],
  );

  /// Fallback page backdrop, shown when a background image is missing or
  /// still decoding.
  static const LinearGradient background = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0B1F4D),
      Color(0xFF1E3A8A),
      Color(0xFF2563EB),
    ],
  );

  /// Translucent so the background still shows through. The alphas are
  /// higher than a pure "tint" because white numbers sit directly on it
  /// and the background images are very pale in places.
  static const LinearGradient heroCard = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xB82563EB), // #2563EB @ 72%
      Color(0xA86366F1), // #6366F1 @ 66%
    ],
  );

  /// Frostier take on [heroCard] for Home's spending card: lower alphas so
  /// more of the (heavily blurred) background shows through. Only used
  /// when blur is on — without blur it would be too thin behind white text.
  static const LinearGradient heroGlass = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x8C3B82F6), // #3B82F6 @ 55%
      Color(0x666366F1), // #6366F1 @ 40%
      Color(0x7A1E3A8A), // #1E3A8A @ 48%
    ],
    stops: [0, 0.55, 1],
  );

  /// Stronger, wider sheen for [heroGlass].
  static const LinearGradient heroSheen = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment(0.5, 0.6),
    colors: [
      Color(0x73FFFFFF), // white @ 45%
      Color(0x14FFFFFF), // white @ 8%
      Color(0x00FFFFFF),
    ],
    stops: [0, 0.45, 1],
  );

  /// Frosted fill for the small icon chips on Home's tiles.
  static const LinearGradient glassIcon = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x59FFFFFF), // white @ 35%
      Color(0x14FFFFFF), // white @ 8%
    ],
  );

  static const LinearGradient block = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x991E3A8A), // #1E3A8A @ 60%
      Color(0x662563EB), // #2563EB @ 40%
    ],
  );

  static const LinearGradient action = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF22D3EE),
      Color(0xFF2563EB),
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

  /// Top-left sheen laid over glass surfaces.
  static const LinearGradient glassHighlight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment(0.2, 0.4),
    colors: [
      Color(0x66FFFFFF), // white @ 40%
      Color(0x00FFFFFF), // white @ 0%
    ],
  );
}

class AppColors {
  // Brand
  static const Color primary = Color(0xFF2563EB);
  static const Color primaryDark = Color(0xFF1E3A8A);
  static const Color deepNavy = Color(0xFF0B1F4D);
  static const Color accentCyan = Color(0xFF22D3EE);
  static const Color accentTeal = Color(0xFF5EEAD4);
  static const Color accentViolet = Color(0xFF6366F1);
  static const Color accentLavender = Color(0xFFA78BFA); // T-bond series
  static const Color accentCyanTint = Color(0x2E22D3EE); // cyan @ 18%, live badges

  // Glass surfaces. The fill is navy-tinted (navy @ 48% under white @ 8%,
  // pre-composited) rather than plain white @ 14%: the background images are
  // pale enough in places that white text on a white-tinted pane drops
  // below WCAG AA. This keeps white text ≥ 5.5:1 on the brightest regions.
  static const Color glassFill = Color(0x85304168);
  static const Color glassFillStrong = Color(0x805A6786);
  /// Panels, tiles and inputs nested *inside* a glass card — a light white
  /// lift instead of a second navy tint.
  static const Color innerFill = Color(0x14FFFFFF); // white @ 8%
  static const Color innerFillSelected = Color(0x33FFFFFF); // white @ 20%
  static const Color glassBorder = Color(0x47FFFFFF); // white @ 28%
  static const Color glassBorderStrong = Color(0x66FFFFFF); // white @ 40%
  static const Color glassShadow = Color(0x400B1F4D); // navy @ 25%

  /// Used instead of [glassFill] when blur is disabled, so the pane still
  /// separates from the background.
  static const Color glassFillNoBlur = Color(0xB31A2A55);

  // Text
  static const Color onGlass = Color(0xFFFFFFFF);
  static const Color onGlassMuted = Color(0xD9FFFFFF); // white @ 85%
  static const Color onGlassFaint = Color(0x99FFFFFF); // white @ 60%
  static const Color onLight = deepNavy;

  // Meaning — pale tones so they stay readable on blue glass.
  static const Color gain = Color(0xFF86EFAC);
  static const Color loss = Color(0xFFFCA5A5);
  static const Color warning = Color(0xFFFCD34D);
  static const Color warningTint = Color(0x33F59E0B); // amber @ 20%
  static const Color gold = Color(0xFFF3C06B);

  /// Solid surfaces for white-text banners (error / success snackbars).
  /// The pale [loss] / [gain] tones are for text and marks, not fills.
  static const Color lossStrong = Color(0xFF9F1239);
  static const Color gainStrong = Color(0xFF166534);

  // Charts
  static const Color chartGrid = Color(0x24FFFFFF); // white @ 14%
  static const Color chartPast = Color(0x4DFFFFFF); // white @ 30%
  static const List<Color> chartSeries = [
    Color(0xFF2563EB),
    Color(0xFF22D3EE),
    Color(0xFF6366F1),
    Color(0xFFF3C06B),
    Color(0xFF5EEAD4),
    Color(0xFFF472B6),
  ];

  /// Readable label color for text drawn on a solid [fill] (pie slices,
  /// bars): navy on light fills like cyan/gold, white on dark ones.
  static Color onFill(Color fill) => fill.computeLuminance() > 0.35 ? onLight : onGlass;

  // Old green-theme names, kept so anything not yet migrated still compiles.
  @Deprecated('Use AppColors.deepNavy')
  static const Color bgLight = deepNavy;
  @Deprecated('Use AppColors.glassFill')
  static const Color cardBg = glassFill;
  @Deprecated('Use AppColors.glassFillStrong')
  static const Color mintBg = glassFillStrong;
  @Deprecated('Use AppColors.glassBorder')
  static const Color borderLight = glassBorder;
  @Deprecated('Use AppColors.onGlass')
  static const Color textDark = onGlass;
  @Deprecated('Use AppColors.onGlassMuted')
  static const Color textMuted = onGlassMuted;
  @Deprecated('Use AppColors.gold')
  static const Color goldAccent = gold;
  @Deprecated('Use AppColors.primary')
  static const Color emerald = primary;
  @Deprecated('Use AppColors.accentCyan')
  static const Color emeraldAccent = accentCyan;
  @Deprecated('Use AppColors.loss')
  static const Color rose = loss;
  @Deprecated('Use AppColors.loss')
  static const Color roseAccent = loss;
  @Deprecated('Use AppColors.loss')
  static const Color roseDark = loss;
}

/// Soft shadow that keeps large white titles legible where they sit
/// directly on the background artwork rather than on a glass pane.
const List<Shadow> kTitleShadow = [
  Shadow(color: Color(0x800B1F4D), blurRadius: 14, offset: Offset(0, 2)),
];

/// Glass rendering switches.
class AppGlass {
  static const double blurSigma = 16;
  static const double radius = 24;

  /// Global switch for BackdropFilter blur. Defaults to off for browsers on
  /// phones/tablets, where CanvasKit blur is the most likely cause of
  /// scroll jank. Set to false in main() to disable everywhere.
  static bool blurEnabled = !(kIsWeb && AppPlatform.isMobileOS);

  /// Whether blur should actually be drawn in this context (also honours the
  /// OS "reduce motion" / disable-animations accessibility setting).
  static bool useBlur(BuildContext context) =>
      blurEnabled && !MediaQuery.disableAnimationsOf(context);

  static List<BoxShadow> get shadow => const [
        BoxShadow(
          color: AppColors.glassShadow,
          blurRadius: 24,
          offset: Offset(0, 8),
        ),
      ];
}

class AppTheme {
  static const Color primaryColor = AppColors.primary;
  static const Color accentColor = AppColors.accentCyan;
  static const Color secondaryColor = AppColors.glassFillStrong;

  static ThemeData get lightTheme {
    final baseTextTheme = AppFonts.textTheme(ThemeData.dark().textTheme)
        .apply(bodyColor: AppColors.onGlass, displayColor: AppColors.onGlass);

    final overlayShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
      side: const BorderSide(color: AppColors.glassBorder),
    );

    OutlineInputBorder inputBorder(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c, width: w),
        );

    final inputTheme = InputDecorationTheme(
      filled: true,
      fillColor: AppColors.glassFillStrong,
      hintStyle: AppFonts.text(color: AppColors.onGlassMuted),
      labelStyle: AppFonts.text(color: AppColors.onGlassMuted),
      floatingLabelStyle: AppFonts.text(color: AppColors.accentCyan),
      prefixIconColor: AppColors.onGlassMuted,
      suffixIconColor: AppColors.onGlassMuted,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: inputBorder(AppColors.glassBorder),
      enabledBorder: inputBorder(AppColors.glassBorder),
      focusedBorder: inputBorder(AppColors.accentCyan, 1.5),
      errorBorder: inputBorder(AppColors.loss),
      focusedErrorBorder: inputBorder(AppColors.loss, 1.5),
      errorStyle: AppFonts.text(color: AppColors.loss),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        onPrimary: Colors.white,
        secondary: AppColors.accentCyan,
        onSecondary: AppColors.deepNavy,
        tertiary: AppColors.accentViolet,
        surface: AppColors.deepNavy,
        onSurface: AppColors.onGlass,
        onSurfaceVariant: AppColors.onGlassMuted,
        surfaceContainerHighest: AppColors.primaryDark,
        outline: AppColors.glassBorderStrong,
        outlineVariant: AppColors.glassBorder,
        error: AppColors.loss,
        onError: AppColors.deepNavy,
      ),
      textTheme: baseTextTheme,
      scaffoldBackgroundColor: AppColors.deepNavy,
      canvasColor: AppColors.deepNavy,
      dividerColor: AppColors.chartGrid,
      dividerTheme: const DividerThemeData(color: AppColors.chartGrid, thickness: 1),
      iconTheme: const IconThemeData(color: AppColors.onGlass),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.onGlass,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppFonts.text(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.onGlass,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.onLight,
          disabledBackgroundColor: AppColors.glassFillStrong,
          disabledForegroundColor: AppColors.onGlassFaint,
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size(64, 52),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          textStyle: AppFonts.text(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.onLight,
          shape: const StadiumBorder(),
          textStyle: AppFonts.text(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.onGlass,
          backgroundColor: AppColors.glassFill,
          side: const BorderSide(color: AppColors.glassBorderStrong),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          textStyle: AppFonts.text(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accentCyan,
          textStyle: AppFonts.text(fontWeight: FontWeight.w700),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: AppColors.onGlass),
      ),
      cardTheme: CardThemeData(
        color: AppColors.glassFill,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppGlass.radius),
          side: const BorderSide(color: AppColors.glassBorder),
        ),
      ),
      inputDecorationTheme: inputTheme,
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.accentCyan,
        selectionColor: Color(0x6622D3EE),
        selectionHandleColor: AppColors.accentCyan,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.deepNavy,
        surfaceTintColor: Colors.transparent,
        shape: overlayShape,
        titleTextStyle: AppFonts.text(
            fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.onGlass),
        contentTextStyle:
            AppFonts.text(fontSize: 14, color: AppColors.onGlassMuted, height: 1.4),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.deepNavy,
        modalBackgroundColor: AppColors.deepNavy,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: AppColors.glassBorderStrong,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          side: BorderSide(color: AppColors.glassBorder),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.deepNavy,
        surfaceTintColor: Colors.transparent,
        shape: overlayShape,
        textStyle: AppFonts.text(color: AppColors.onGlass),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: AppFonts.text(color: AppColors.onGlass),
        inputDecorationTheme: inputTheme,
        menuStyle: const MenuStyle(
          backgroundColor: WidgetStatePropertyAll(AppColors.deepNavy),
          surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      menuTheme: const MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(AppColors.deepNavy),
          surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.deepNavy,
        contentTextStyle: AppFonts.text(color: AppColors.onGlass, fontSize: 14),
        actionTextColor: AppColors.accentCyan,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.glassBorder),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.deepNavy,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.glassBorder),
        ),
        textStyle: AppFonts.text(color: AppColors.onGlass, fontSize: 12),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: AppColors.deepNavy,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: AppColors.primaryDark,
        headerForegroundColor: AppColors.onGlass,
        dividerColor: AppColors.glassBorder,
        shape: overlayShape,
        dayForegroundColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? AppColors.onLight : AppColors.onGlass),
        dayBackgroundColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? Colors.white : null),
        todayForegroundColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? AppColors.onLight : AppColors.accentCyan),
        todayBorder: const BorderSide(color: AppColors.accentCyan),
        yearForegroundColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? AppColors.onLight : AppColors.onGlass),
        yearBackgroundColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? Colors.white : null),
        cancelButtonStyle: TextButton.styleFrom(foregroundColor: AppColors.onGlassMuted),
        confirmButtonStyle: TextButton.styleFrom(foregroundColor: AppColors.accentCyan),
        inputDecorationTheme: inputTheme,
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: AppColors.deepNavy,
        shape: overlayShape,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accentCyan,
        linearTrackColor: AppColors.chartGrid,
        circularTrackColor: Colors.transparent,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? Colors.white : AppColors.onGlassMuted),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? AppColors.primary : AppColors.glassFillStrong),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? Colors.white : Colors.transparent),
        checkColor: const WidgetStatePropertyAll(AppColors.onLight),
        side: const BorderSide(color: AppColors.glassBorderStrong, width: 1.5),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.glassFill,
        selectedColor: Colors.white,
        side: const BorderSide(color: AppColors.glassBorder),
        labelStyle: AppFonts.text(color: AppColors.onGlass),
        secondaryLabelStyle: AppFonts.text(color: AppColors.onLight),
        shape: const StadiumBorder(),
      ),
      listTileTheme: const ListTileThemeData(
        textColor: AppColors.onGlass,
        iconColor: AppColors.onGlassMuted,
      ),
    );
  }

  /// The glass theme is dark by construction; both modes use it.
  static ThemeData get darkTheme => lightTheme;
}
