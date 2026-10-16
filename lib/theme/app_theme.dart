import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Barkat Nikah design tokens — reverse-engineered from the Barkat app
/// (Play Store screenshots, pixel-sampled).
///
/// All screens must read colors from this file instead of hardcoding hex
/// values inline. [canvas] is the mint app background, [green] the brand
/// forest green used on primary actions, [gold] the metallic accent used on
/// Request Contact / badges, and the [slate] scale is the neutral companion.
class AppTheme {
  AppTheme._();

  // ─── Brand: Forest Green ───────────────────────────────────────────────────
  /// Darkest pine — dark hero/deck backgrounds (sampled #1A1A1A–#124836 mix).
  static const Color emeraldDeep = Color(0xFF0D3327);

  /// Mid pine — elevated dark surfaces.
  static const Color emerald = Color(0xFF185A42);

  /// Primary brand green — buttons, active states, links (sampled #185A42).
  static const Color green = Color(0xFF185A42);

  /// Bright leaf green — icons/text on dark surfaces (sampled from card rows).
  static const Color mint = Color(0xFF8FE0B0);

  /// Soft sage — secondary green fills.
  static const Color sage = Color(0xFF8FD3AB);

  // ─── Accent: Gold ──────────────────────────────────────────────────────────
  /// Light champagne — badge pills, light gold surfaces (sampled #F5E9C8).
  static const Color gold = Color(0xFFE9D9A0);

  /// Metallic gold — Request Contact, borders, ratings (sampled #D9BA58).
  static const Color goldAccent = Color(0xFFD9BA58);

  /// Deep bronze — text on gold surfaces.
  static const Color goldDeep = Color(0xFF7A5E22);

  /// Ink on gold — high-contrast gold text.
  static const Color goldInk = Color(0xFF33270A);

  // ─── Neutrals: mint canvas ────────────────────────────────────────────────
  /// Pure white cards.
  static const Color ivory = Color(0xFFFFFFFF);

  /// Warm cream — premium / marketing surfaces (sampled #FBF9F2).
  static const Color ivoryWarm = Color(0xFFF7F5EE);

  /// Mint app background (sampled #F1FBF4).
  static const Color canvas = Color(0xFFF1FBF4);

  /// Marketing cream used on landing frames (sampled #EBEADE).
  static const Color cream = Color(0xFFEBEADE);

  /// Near-black ink for text and dark chips (sampled #1A1A1A).
  static const Color ink = Color(0xFF1A1A1A);

  /// Muted gray for outlines / neutral icons.
  static const Color outline = Color(0xFF7C817C);

  // ─── Neutral slate scale (secondary text, borders, fills) ──────────────────
  static const Color slate900 = Color(0xFF141514);
  static const Color slate800 = Color(0xFF232523);
  static const Color slate700 = Color(0xFF3E413E);
  static const Color slate600 = Color(0xFF5A5E5A);
  static const Color slate500 = Color(0xFF7C817C);
  static const Color slate400 = Color(0xFFA1A6A1);
  static const Color slate300 = Color(0xFFD6DCD6);
  static const Color slate200 = Color(0xFFE4EAE5);
  static const Color slate100 = Color(0xFFF0F5F0);

  // ─── Status ────────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF1E8A50);
  static const Color successBg = Color(0xFFE3F8E8);
  static const Color warning = Color(0xFF9A6A00);
  static const Color warningBg = Color(0xFFFCF3E0);
  static const Color danger = Color(0xFFEF4444);
  static const Color dangerBg = Color(0xFFFDECEC);
  static const Color info = Color(0xFF1D4ED8);
  static const Color infoBg = Color(0xFFE8EFFD);

  // ─── Compatibility aliases (older screens) ────────────────────────────────
  static const Color primary = emeraldDeep;
  static const Color primaryContainer = emerald;
  static const Color secondary = green;
  static const Color secondaryContainer = mint;
  static const Color surfaceIvory = ivory;
  static const Color surfaceWarm = ivoryWarm;
  static const Color background = canvas;
  static const Color onSurface = ink;
  static const Color goldLight = gold;

  /// Dark brand wash behind hero / deck / header areas.
  static const LinearGradient brandWash = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF08251B), emeraldDeep, emerald],
  );

  /// Bottom fade used on profile photos so overlays stay legible.
  static const LinearGradient deckPhotoScrim = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    stops: [0, 0.45, 0.75],
    colors: [Color(0xF20D3327), Color(0x800D3327), Color(0x000D3327)],
  );

  static const String fontFamily = 'PlusJakartaSans';

  static TextStyle ts(
    double size,
    FontWeight weight, {
    Color color = ink,
    double? height,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  // Frequently reused styles.
  static final TextStyle h1 = ts(28, FontWeight.w800, color: slate900, height: 1.2);
  static final TextStyle h2 = ts(22, FontWeight.w800, color: slate900, height: 1.25);
  static final TextStyle h3 = ts(18, FontWeight.w700, color: slate900, height: 1.3);
  static final TextStyle bodyLarge = ts(16, FontWeight.w500, color: slate700, height: 1.4);
  static final TextStyle body = ts(14.5, FontWeight.w500, color: slate700, height: 1.45);
  static final TextStyle bodySmall = ts(13, FontWeight.w500, color: slate500, height: 1.45);
  static final TextStyle caption = ts(12, FontWeight.w600, color: slate500);
  static final TextStyle overline = ts(
    11,
    FontWeight.w700,
    color: slate500,
    letterSpacing: 1.4,
  );

  static ThemeData get lightTheme {
    final base = ThemeData(
      useMaterial3: true,
      // Touch the GoogleFonts helper once so the runtime font loader
      // registers the Plus Jakarta Sans family, then style everything
      // through the app tokens below.
      fontFamily: GoogleFonts.plusJakartaSans().fontFamily ?? fontFamily,
      scaffoldBackgroundColor: canvas,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: green,
        onPrimary: Colors.white,
        primaryContainer: emerald,
        onPrimaryContainer: mint,
        secondary: goldAccent,
        onSecondary: goldInk,
        secondaryContainer: successBg,
        onSecondaryContainer: emeraldDeep,
        surface: ivory,
        onSurface: ink,
        error: danger,
        onError: Colors.white,
      ),
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        titleLarge: h2,
        titleMedium: h3,
        bodyLarge: bodyLarge,
        bodyMedium: body,
        bodySmall: bodySmall,
        labelSmall: caption,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: slate900,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: slate800),
      ),
      // Barkat bottom nav: active item is near-black ink, inactive gray.
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: ink,
        unselectedItemColor: slate400,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: slate200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: slate200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: green, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: danger, width: 1.6),
        ),
        hintStyle: TextStyle(fontFamily: fontFamily, color: slate400),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: green,
          foregroundColor: Colors.white,
          disabledBackgroundColor: slate300,
          disabledForegroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: ts(15, FontWeight.w700, color: Colors.white, letterSpacing: 0.2),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: const BorderSide(color: slate300),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: ts(14, FontWeight.w700, color: ink),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: green,
          textStyle: ts(14, FontWeight.w700),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? Colors.white : slate300,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? green : slate300,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? green : Colors.white,
        ),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: const BorderSide(color: slate300),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? green : slate300,
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: green,
        thumbColor: green,
        overlayColor: Color(0x22185A42),
        inactiveTrackColor: slate200,
        trackHeight: 4,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: slate100,
        side: const BorderSide(color: slate200),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        labelStyle: ts(12.5, FontWeight.w600, color: slate700),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: slate900,
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: Colors.white,
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: ts(18, FontWeight.w800, color: slate900),
        contentTextStyle: ts(14, FontWeight.w500, color: slate600, height: 1.5),
      ),
      dividerTheme: const DividerThemeData(color: slate200, thickness: 1, space: 1),
      shadowColor: ink.withValues(alpha: 0.06),
    );
  }
}
