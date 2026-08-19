import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../theme/design_tokens.dart';

/// Selector de una sola opción en chips (equivalente a `Chips` en
/// `register.tsx`). No usa `ChoiceChip` de Material para calcar el estilo
/// exacto del mockup: fondo plano lleno cuando está activo, en vez de un
/// contorno con relleno tenue.
class SingleChoiceChips extends StatelessWidget {
  const SingleChoiceChips({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.stacked = false,
  });

  final List<String> options;
  final String? value;
  final ValueChanged<String> onChanged;

  /// Si es true, las opciones se apilan en columna a ancho completo en vez
  /// de envolver en una fila (usado en el paso "Objetivo" del mockup).
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final chips = options
        .map((o) => _Chip(
              label: o,
              active: o == value,
              stacked: stacked,
              onTap: () => onChanged(o),
            ))
        .toList();

    if (!stacked) {
      return Wrap(spacing: 8, runSpacing: 8, children: chips);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < chips.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          chips[i],
        ],
      ],
    );
  }
}

/// Selector multi-opción con checkmark cuando está activo (equivalente a
/// `MultiChips`).
class MultiChoiceChips extends StatelessWidget {
  const MultiChoiceChips({
    super.key,
    required this.options,
    required this.values,
    required this.onChanged,
    this.stacked = false,
  });

  final List<String> options;
  final List<String> values;
  final ValueChanged<List<String>> onChanged;

  /// Igual que en `SingleChoiceChips`: apila a ancho completo en vez de
  /// envolver en una fila (útil para listas de opciones más largas).
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final chips = options.map((o) {
      final active = values.contains(o);
      return _Chip(
        label: o,
        active: active,
        stacked: stacked,
        showCheck: active,
        onTap: () => onChanged(
          active ? values.where((v) => v != o).toList() : [...values, o],
        ),
      );
    }).toList();

    if (!stacked) {
      return Wrap(spacing: 8, runSpacing: 8, children: chips);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < chips.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          chips[i],
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.active,
    required this.onTap,
    this.stacked = false,
    this.showCheck = false,
  });

  final String label;
  final bool active;
  final bool stacked;
  final bool showCheck;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final foreground = DesignTokens.foreground(b);
    final background = DesignTokens.background(b);
    final surface1 = DesignTokens.surface1(b);
    final border = DesignTokens.border(b);
    final radius = BorderRadius.circular(DesignTokens.radius2xl);

    return Material(
      type: MaterialType.transparency,
      child: Ink(
        decoration: BoxDecoration(
          color: active ? foreground : surface1,
          borderRadius: radius,
          border: active ? null : Border.all(color: border),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment:
                  stacked ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                if (showCheck) ...[
                  Icon(LucideIcons.check, size: 14, color: background),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    label,
                    style: DesignTokens.bodyFont(
                      fontSize: 13.5,
                      weight: FontWeight.w600,
                      color: active ? background : foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
