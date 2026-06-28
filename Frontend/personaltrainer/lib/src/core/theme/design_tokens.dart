import 'package:flutter/material.dart';

/// Design tokens extraídos del design system de Lovable (styles.css),
/// traducidos de OKLCH a Color (aproximación RGB).
/// Mantén el mismo ADN visual: minimalist, Apple-like, glassmorphism,
/// gradiente AI y modo claro/oscuro.
class DesignTokens {
  DesignTokens._();

  // ===== Luz =====
  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightForeground = Color(0xFF1B1B20);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightCardForeground = Color(0xFF1B1B20);
  static const Color lightMuted = Color(0xFFF1F1F4);
  static const Color lightMutedForeground = Color(0xFF7E7E89);
  static const Color lightAccent = Color(0xFFF1F1F4);
  static const Color lightBorder = Color(0xFFE9E9EC);
  static const Color lightInput = Color(0xFFE9E9EC);
  static const Color lightRing = Color(0xFF8E8EBA);
  static const Color lightSurface1 = Color(0xFFFAFAFB);
  static const Color lightSurface2 = Color(0xFFF3F3F6);
  static const Color lightDestructive = Color(0xFFE5484D);

  // ===== Oscura =====
  static const Color darkBackground = Color(0xFF111318);
  static const Color darkForeground = Color(0xFFF9F9FC);
  static const Color darkCard = Color(0xFF23262F);
  static const Color darkCardForeground = Color(0xFFF9F9FC);
  static const Color darkMuted = Color(0xFF3A3D49);
  static const Color darkMutedForeground = Color(0xFF9DA0AE);
  static const Color darkAccent = Color(0xFF3A3D49);
  static const Color darkBorder = Color(0x1AFFFFFF);
  static const Color darkInput = Color(0x26FFFFFF);
  static const Color darkRing = Color(0xFF7E8AB8);
  static const Color darkSurface1 = Color(0xFF1B1D24);
  static const Color darkSurface2 = Color(0xFF1A1C22);
  static const Color darkDestructive = Color(0xFFEF5A5F);

  // ===== Gradiente AI (común) =====
  // oklch(0.72 0.18 295) → oklch(0.7 0.19 260) → oklch(0.78 0.17 200)
  static const Color aiFrom = Color(0xFFB054F0);
  static const Color aiVia = Color(0xFF6A5CF0);
  static const Color aiTo = Color(0xFF46B5E8);

  static const LinearGradient aiGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [aiFrom, aiVia, aiTo],
    stops: [0.0, 0.55, 1.0],
  );

  /// Soft AI gradient (versiones difuminadas para rellenos suaves).
  static const LinearGradient aiGradientSoft = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEEDBFC), Color(0xFFDCEBFB)],
  );

  // ===== Acento ámbar (alertas) =====
  static const LinearGradient warnSoft = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFBE8B0), Color(0xFFF4D785)],
  );

  // ===== Chart colors =====
  static const Color chart1 = Color(0xFFE76F51);
  static const Color chart2 = Color(0xFF2A9D8F);
  static const Color chart3 = Color(0xFF264653);
  static const Color chart4 = Color(0xFFE9C46A);
  static const Color chart5 = Color(0xFFF4A261);

  // ===== Helpers por brightness =====
  static Color background(Brightness b) =>
      b == Brightness.dark ? darkBackground : lightBackground;
  static Color foreground(Brightness b) =>
      b == Brightness.dark ? darkForeground : lightForeground;
  static Color card(Brightness b) =>
      b == Brightness.dark ? darkCard : lightCard;
  static Color cardForeground(Brightness b) =>
      b == Brightness.dark ? darkCardForeground : lightCardForeground;
  static Color muted(Brightness b) =>
      b == Brightness.dark ? darkMuted : lightMuted;
  static Color mutedForeground(Brightness b) =>
      b == Brightness.dark ? darkMutedForeground : lightMutedForeground;
  static Color border(Brightness b) =>
      b == Brightness.dark ? darkBorder : lightBorder;
  static Color surface1(Brightness b) =>
      b == Brightness.dark ? darkSurface1 : lightSurface1;
  static const surface2 = Color(0xFFF3F3F6);
  static Color surface2of(Brightness b) =>
      b == Brightness.dark ? darkSurface2 : lightSurface2;
  static Color ring(Brightness b) =>
      b == Brightness.dark ? darkRing : lightRing;
  static Color destructive(Brightness b) =>
      b == Brightness.dark ? darkDestructive : lightDestructive;

  // Radios del design system (0.625rem base)
  static const double radius = 10.0;
  static const double radiusSm = 6.0;
  static const double radiusMd = 8.0;
  static const double radiusLg = 10.0;
  static const double radiusXl = 14.0;
  static const double radius2xl = 18.0;
  static const double radius3xl = 22.0;
  static const double radius4xl = 26.0;
  static const double cardRadius = 28.0;

  // Sombras (shadow-soft / shadow-card)
  static List<BoxShadow> shadowSoft(Brightness b) => [
        BoxShadow(
          color: b == Brightness.dark
              ? Colors.black.withOpacity(0.28)
              : const Color(0x1A0B1220),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: b == Brightness.dark
              ? Colors.black.withOpacity(0.20)
              : const Color(0x080B1220),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> shadowCard(Brightness b) => [
        BoxShadow(
          color: b == Brightness.dark
              ? Colors.black.withOpacity(0.42)
              : const Color(0x1F0B1220),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: b == Brightness.dark
              ? Colors.black.withOpacity(0.28)
              : const Color(0x0A0B1220),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
      ];
}