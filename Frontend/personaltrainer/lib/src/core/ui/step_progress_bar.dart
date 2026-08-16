import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Barra de progreso segmentada para wizards multi-paso (equivalente al
/// stepper de `register.tsx`): cada segmento es hecho / actual (gradiente
/// IA) / futuro.
class StepProgressBar extends StatelessWidget {
  const StepProgressBar({
    super.key,
    required this.steps,
    required this.current,
  });

  final int steps;
  final int current;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final surface1 = DesignTokens.surface1(b);
    final foreground = DesignTokens.foreground(b);

    return Row(
      children: List.generate(steps, (i) {
        final isDone = i < current;
        final isCurrent = i == current;
        return Expanded(
          child: Container(
            height: 6,
            margin: EdgeInsets.only(right: i == steps - 1 ? 0 : 6),
            decoration: BoxDecoration(
              gradient: isCurrent ? DesignTokens.aiGradient : null,
              color: isCurrent
                  ? null
                  : (isDone ? foreground.withOpacity(0.7) : surface1),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      }),
    );
  }
}
