import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'design_tokens.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final background = DesignTokens.background(b);
    final foreground = DesignTokens.foreground(b);
    final card = DesignTokens.card(b);
    final muted = DesignTokens.muted(b);
    final mutedFg = DesignTokens.mutedForeground(b);
    final border = DesignTokens.border(b);
    final ring = DesignTokens.ring(b);
    final destructive = DesignTokens.destructive(b);

    final baseTextTheme = TextTheme(
      displaySmall: GoogleFonts.outfit(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.0,
        color: foreground,
        height: 1.2,
      ),
      displayMedium: GoogleFonts.outfit(
        fontSize: 40,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.2,
        color: foreground,
      ),
      headlineMedium: GoogleFonts.outfit(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: foreground,
      ),
      headlineSmall: GoogleFonts.outfit(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: foreground,
      ),
      titleLarge: GoogleFonts.manrope(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: foreground,
      ),
      titleMedium: GoogleFonts.manrope(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: foreground,
      ),
      bodyLarge: GoogleFonts.manrope(
        fontSize: 16,
        color: foreground,
        height: 1.5,
      ),
      bodyMedium: GoogleFonts.manrope(
        fontSize: 14,
        color: foreground,
        height: 1.4,
      ),
      bodySmall: GoogleFonts.manrope(
        fontSize: 12,
        color: mutedFg,
        height: 1.4,
      ),
      labelMedium: GoogleFonts.manrope(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: mutedFg,
      ),
      labelSmall: GoogleFonts.manrope(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.4,
        color: mutedFg,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: b,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme(
        brightness: b,
        primary: foreground,
        onPrimary: background,
        secondary: mutedFg,
        onSecondary: background,
        surface: card,
        onSurface: foreground,
        error: destructive,
        onError: background,
      ),
      textTheme: baseTextTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: foreground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.cardRadius),
          side: BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
          borderSide: BorderSide(color: ring, width: 1.6),
        ),
        hintStyle: GoogleFonts.manrope(fontSize: 14, color: mutedFg),
        labelStyle: GoogleFonts.manrope(fontSize: 14, color: mutedFg),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: foreground,
          foregroundColor: background,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: GoogleFonts.manrope(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: foreground,
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: GoogleFonts.manrope(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      dividerColor: border,
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: foreground,
        contentTextStyle: GoogleFonts.manrope(color: background),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(DesignTokens.cardRadius),
        ),
      ),
    );
  }
}