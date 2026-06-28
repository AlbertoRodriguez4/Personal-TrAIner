import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Tarjeta con efecto "glassmorphism" de Lovable:
/// fondo translúcido, saturación 180%, blur 20px y borde translúcido.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    this.child,
    this.radius = 28,
    this.padding = const EdgeInsets.all(16),
    this.shadow = true,
  });

  final Widget? child;
  final double radius;
  final EdgeInsets padding;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final isDark = b == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.white.withOpacity(0.70),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.10)
                  : Colors.white.withOpacity(0.60),
            ),
            boxShadow: shadow ? DesignTokens.shadowCard(b) : null,
          ),
          child: child,
        ),
      ),
    );
  }
}