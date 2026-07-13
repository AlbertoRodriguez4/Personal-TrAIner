import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../core/ui/ai_gradient_text.dart';

class FocusModePage extends StatefulWidget {
  const FocusModePage({super.key});

  @override
  State<FocusModePage> createState() => _FocusModePageState();
}

class _FocusModePageState extends State<FocusModePage> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _isCameraActive = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final bg = DesignTokens.background(b);
    final fg = DesignTokens.foreground(b);
    final mutedFg = DesignTokens.mutedForeground(b);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: fg),
          onPressed: () => Navigator.pop(context),
        ),
        title: AiGradientText(
          'FOCUS MODE',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 1.5),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _isCameraActive ? _buildCameraView(b, fg) : _buildIdleView(b, fg, mutedFg),
            ),
            _buildControls(b, fg, mutedFg),
          ],
        ),
      ),
    );
  }

  Widget _buildIdleView(Brightness b, Color fg, Color mutedFg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: DesignTokens.aiGradientSoft,
              ),
              child: Icon(LucideIcons.scanFace, size: 48, color: fg.withOpacity(0.8)),
            ),
            const SizedBox(height: 32),
            Text(
              'Edge AI Tracker',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: fg),
            ),
            const SizedBox(height: 12),
            Text(
              'Análisis cinemático en tiempo real.\nColoca tu móvil apoyado donde se vea tu cuerpo completo.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: mutedFg, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraView(Brightness b, Color fg) {
    return Container(
      margin: const EdgeInsets.all(20),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DesignTokens.cardRadius),
        boxShadow: DesignTokens.shadowCard(b),
        gradient: RadialGradient(
          center: const Alignment(0, -0.2),
          colors: [DesignTokens.muted(b), DesignTokens.surface2of(b)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Simulate camera feed (just a dark background)
          Container(color: Colors.black87),
          
          // Pose skeleton mock
          CustomPaint(painter: _SkeletonPainter()),

          // Scanning effect overlay
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Positioned(
                top: (_pulseController.value * MediaQuery.of(context).size.height * 0.6),
                left: 0,
                right: 0,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: DesignTokens.aiVia.withOpacity(0.5),
                        blurRadius: 12,
                        spreadRadius: 2,
                      )
                    ],
                    gradient: LinearGradient(
                      colors: [
                        DesignTokens.aiVia.withOpacity(0),
                        DesignTokens.aiVia,
                        DesignTokens.aiVia.withOpacity(0),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // Top left badge
          Positioned(
            top: 20,
            left: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'TRACKING ACTIVO',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Rep counter overlay
          Positioned(
            bottom: 30,
            right: 30,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
                border: Border.all(color: DesignTokens.aiVia, width: 2),
              ),
              child: const Text(
                '7',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(Brightness b, Color fg, Color mutedFg) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      decoration: BoxDecoration(
        color: DesignTokens.card(b),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: DesignTokens.shadowCard(b),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('EJERCICIO 3 / 8',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.4, color: mutedFg)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: DesignTokens.aiGradientSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('Edge AI', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: fg),
              children: [
                const TextSpan(text: 'Press Inclinado'),
                TextSpan(text: ' · Mancuernas', style: TextStyle(color: mutedFg, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _MetaBig(value: '4', unit: 'series', fg: fg, mutedFg: mutedFg),
              const SizedBox(width: 24),
              _MetaBig(value: '8–10', unit: 'reps', fg: fg, mutedFg: mutedFg),
              const SizedBox(width: 24),
              _MetaBig(value: '22kg', unit: 'objetivo', fg: fg, mutedFg: mutedFg),
            ],
          ),
          const SizedBox(height: 24),
          InkWell(
            onTap: () {
              setState(() {
                _isCameraActive = !_isCameraActive;
              });
            },
            borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                gradient: DesignTokens.aiGradient,
                borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
                boxShadow: DesignTokens.shadowCard(b),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_isCameraActive ? LucideIcons.stopCircle : LucideIcons.camera, size: 20, color: Colors.white),
                  const SizedBox(width: 10),
                  Text(
                    _isCameraActive ? 'Detener Tracking' : 'Activar Cámara Edge AI',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaBig extends StatelessWidget {
  const _MetaBig({required this.value, required this.unit, required this.fg, required this.mutedFg});
  final String value;
  final String unit;
  final Color fg;
  final Color mutedFg;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: fg)),
        Text(unit, style: TextStyle(fontSize: 12, color: mutedFg, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _SkeletonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = DesignTokens.aiVia.withOpacity(0.6)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final jointPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Simulate a simple stick figure skeleton
    final center = Offset(size.width / 2, size.height * 0.4);
    
    // Spine
    final neck = center;
    final hip = Offset(center.dx, center.dy + 120);
    canvas.drawLine(neck, hip, paint);

    // Shoulders & Arms
    final lShoulder = Offset(center.dx - 40, center.dy + 10);
    final rShoulder = Offset(center.dx + 40, center.dy + 10);
    canvas.drawLine(lShoulder, rShoulder, paint);

    final lElbow = Offset(lShoulder.dx - 30, lShoulder.dy + 40);
    final rElbow = Offset(rShoulder.dx + 30, rShoulder.dy + 40);
    canvas.drawLine(lShoulder, lElbow, paint);
    canvas.drawLine(rShoulder, rElbow, paint);

    // Hips & Legs
    final lHip = Offset(hip.dx - 20, hip.dy);
    final rHip = Offset(hip.dx + 20, hip.dy);
    canvas.drawLine(lHip, rHip, paint);

    final lKnee = Offset(lHip.dx - 10, lHip.dy + 80);
    final rKnee = Offset(rHip.dx + 10, rHip.dy + 80);
    canvas.drawLine(lHip, lKnee, paint);
    canvas.drawLine(rHip, rKnee, paint);

    // Draw joints
    final joints = [neck, hip, lShoulder, rShoulder, lElbow, rElbow, lHip, rHip, lKnee, rKnee];
    for (var j in joints) {
      canvas.drawCircle(j, 6, jointPaint);
      canvas.drawCircle(j, 4, paint..style = PaintingStyle.fill..color = DesignTokens.aiFrom);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
