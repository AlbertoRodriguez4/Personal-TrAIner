import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Anillo de progreso con gradiente AI (equivalente a `SummaryRing`/`MetricRing`).
class MetricRing extends StatelessWidget {
  const MetricRing({
    super.key,
    required this.value,
    required this.unit,
    this.pct = 0.72,
    this.diameter = 72,
    this.stroke = 6,
    this.sub,
  });

  final String value;
  final String unit;
  final double pct;
  final double diameter;
  final double stroke;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final muted = DesignTokens.muted(b);
    final fg = DesignTokens.foreground(b);
    final mutedFg = DesignTokens.mutedForeground(b);
    final radius = (diameter / 2) - stroke;

    return SizedBox(
      width: diameter,
      height: diameter,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(diameter, diameter),
            painter: _RingPainter(
              radius: radius,
              stroke: stroke,
              trackColor: muted,
              pct: pct.clamp(0.0, 1.0),
            ),
          ),
          RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: fg,
                  ),
              children: [
                TextSpan(text: value),
                TextSpan(
                  text: ' $unit',
                  style: TextStyle(
                    fontSize: 10,
                    color: mutedFg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (sub != null)
                  TextSpan(
                    text: '\n$sub',
                    style: TextStyle(
                      fontSize: 10,
                      color: mutedFg,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.radius,
    required this.stroke,
    required this.trackColor,
    required this.pct,
  });

  final double radius;
  final double stroke;
  final Color trackColor;
  final double pct;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    final sweep = 3.14159265 * 2 * pct;
    canvas.drawArc(
      rect,
      -3.14159265 / 2,
      sweep,
      false,
      Paint()
        ..shader = DesignTokens.aiGradient.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.pct != pct || old.trackColor != trackColor;
}