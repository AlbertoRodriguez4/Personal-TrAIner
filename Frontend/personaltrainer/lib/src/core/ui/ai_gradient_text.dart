import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Texto con relleno del gradiente AI (equivalente a `text-ai-gradient`).
class AiGradientText extends StatelessWidget {
  const AiGradientText(
    this.text, {
    super.key,
    this.style,
  });

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) =>
          DesignTokens.aiGradient.createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: Text(text, style: style),
    );
  }
}