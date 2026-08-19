import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Botón circular de icono usado en las cabeceras de las pantallas
/// (volver, ajustes, refrescar…).
///
/// Unifica las cuatro copias privadas que había en clinic/devices/progress/
/// recovery. Los valores por defecto son los de esas copias; `bordered` e
/// `iconSize` existen para cubrir la variante de clinic sin cambiar su aspecto.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 40,
    this.iconSize,
    this.fillColor,
    this.bordered = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;

  /// Por defecto, proporcional al tamaño del botón (40 → 16).
  final double? iconSize;

  /// Por defecto `DesignTokens.surface1`.
  final Color? fillColor;

  /// Añade el borde de 1px del token `border`.
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fillColor ?? DesignTokens.surface1(b),
          border: bordered ? Border.all(color: DesignTokens.border(b)) : null,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: iconSize ?? size * 0.4,
          color: DesignTokens.foreground(b),
        ),
      ),
    );
  }
}
