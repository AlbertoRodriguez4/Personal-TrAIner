import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/theme/design_tokens.dart';

/// Modo entrenamiento activo — réplica de `focus.tsx`.
///
/// Reutiliza el patrón visual del HR graph painter de
/// `routine/presentation/screens/workout_session_page.dart` (sus widgets son
/// privados, así que aquí se reimplementa el pintor con los tokens
/// centralizados, sin duplicar lógica de timers/sets del provider). Estos
/// valores se inyectan/actualizan desde el host (p. ej. desde el provider de
/// sesión de `workout_session_page.dart`).
class FocusPage extends StatefulWidget {
  const FocusPage({
    super.key,
    required this.exerciseTitle,
    required this.seriesLabel,
    required this.restTotalSeconds,
    required this.defaultWeight,
    required this.defaultReps,
    required this.defaultRpe,
    this.onBack,
    this.onCompleteSet,
    this.onVoiceInput,
  });

  final String exerciseTitle; // ej. "Press Militar"
  final String seriesLabel; // ej. "Serie 3 de 4"
  final int restTotalSeconds;
  final double defaultWeight;
  final int defaultReps;
  final double defaultRpe;
  final VoidCallback? onBack;
  final VoidCallback? onCompleteSet;
  final VoidCallback? onVoiceInput;

  @override
  State<FocusPage> createState() => _FocusPageState();
}

class _FocusPageState extends State<FocusPage> {
  late double _weight;
  late int _reps;
  late double _rpe;
  late int _heartRate;
  late int _restTime;
  bool _isResting = true;
  final _hrPoints = <double>[];

  @override
  void initState() {
    super.initState();
    _weight = widget.defaultWeight;
    _reps = widget.defaultReps;
    _rpe = widget.defaultRpe;
    _heartRate = 148;
    _restTime = widget.restTotalSeconds;
    _hrPoints.addAll(List.generate(100, (_) => 0.45 + math.Random().nextDouble() * 0.25));
    _tickHr();
    _tickRest();
  }

  void _tickHr() {
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() {
        _heartRate = (_heartRate + ((math.Random().nextDouble() - 0.5) * 3).round()).clamp(100, 180);
      });
      _tickHr();
    });
  }

  void _tickRest() {
    if (!_isResting) return;
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted || !_isResting) return;
      setState(() {
        _restTime = math.max(0, _restTime - 1);
        if (_restTime == 0) _isResting = false;
        // nuevos puntos del HR graph
        final base = _heartRate / 200;
        _hrPoints.removeAt(0);
        _hrPoints.add((base + (math.Random().nextDouble() - 0.5) * 0.12).clamp(0.15, 0.9));
      });
      _tickRest();
    });
  }

  ({Color color, Color bg, String label}) _zone(int hr) {
    if (hr < 120) return (color: DesignTokens.hrZoneRecovery, bg: DesignTokens.hrZoneRecovery.withOpacity(0.20), label: 'Recuperación');
    if (hr < 140) return (color: DesignTokens.hrZoneCardio, bg: DesignTokens.hrZoneCardio.withOpacity(0.20), label: 'Cardio');
    if (hr < 160) return (color: DesignTokens.hrZoneHigh, bg: DesignTokens.hrZoneHigh.withOpacity(0.20), label: 'Alta Intensidad');
    return (color: DesignTokens.hrZonePeak, bg: DesignTokens.hrZonePeak.withOpacity(0.20), label: 'Pico');
  }

  @override
  Widget build(BuildContext context) {
    final zone = _zone(_heartRate);
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        bottom: false,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Stack(
            children: [
              // Ambient glow
              Positioned(
                top: -200,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Container(
                    height: 500,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x1A22D3EE), Color(0x0D8B5CF6), Colors.transparent],
                      ),
                    ),
                  ),
                ),
              ),
              Column(
                children: [
                  _Header(title: widget.exerciseTitle, sub: widget.seriesLabel, onBack: widget.onBack),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
                      child: Column(
                        children: [
                          _HeartRateCard(
                            heartRate: _heartRate,
                            points: _hrPoints,
                            zoneColor: zone.color,
                            zoneBg: zone.bg,
                            zoneLabel: zone.label,
                          ),
                          const SizedBox(height: 16),
                          _ExerciseInputs(
                            weight: _weight,
                            reps: _reps,
                            rpe: _rpe,
                            onWeight: (v) => setState(() => _weight = math.max(0, v)),
                            onReps: (v) => setState(() => _reps = math.max(0, v.round())),
                            onRpe: (v) => setState(() => _rpe = math.max(0, v)),
                          ),
                          const SizedBox(height: 16),
                          _AiRestCard(
                            restTime: _restTime,
                            maxTime: widget.restTotalSeconds,
                            isResting: _isResting,
                            onVoice: widget.onVoiceInput,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  minimum: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 430),
                      child: _CompleteSetButton(onTap: widget.onCompleteSet),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ─────────────────────── Header ─────────────────────── */

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.sub, this.onBack});
  final String title;
  final String sub;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
      child: Column(
        children: [
          Row(
            children: [
              _GlassCircle(icon: LucideIcons.chevronLeft, onTap: onBack ?? () => Navigator.maybePop(context)),
              Expanded(
                child: Center(
                  child: RichText(
                    text: TextSpan(
                      style: DesignTokens.bodyFont(fontSize: 11, weight: FontWeight.w500, color: Colors.white54),
                      children: const [
                        TextSpan(text: 'Personal Tr'),
                        TextSpan(text: 'AI', style: TextStyle(fontWeight: FontWeight.bold)),
                        TextSpan(text: 'ner'),
                      ],
                    ),
                  ),
                ),
              ),
              const _GlassCircle(icon: LucideIcons.pause),
            ],
          ),
          const SizedBox(height: 24),
          Text(title, style: DesignTokens.titleFont(fontSize: 28, color: Colors.white, letterSpacing: -0.5, weight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(sub, style: DesignTokens.bodyFont(fontSize: 15, weight: FontWeight.w500, color: Colors.white54)),
        ],
      ),
    );
  }
}

class _GlassCircle extends StatelessWidget {
  const _GlassCircle({required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xCC111111),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 44, height: 44, child: Icon(icon, size: 24, color: Colors.white.withOpacity(0.9))),
        ),
      );
}

/* ─────────────────────── Heart rate card ─────────────────────── */

class _HeartRateCard extends StatelessWidget {
  const _HeartRateCard({
    required this.heartRate,
    required this.points,
    required this.zoneColor,
    required this.zoneBg,
    required this.zoneLabel,
  });
  final int heartRate;
  final List<double> points;
  final Color zoneColor, zoneBg;
  final String zoneLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0x99111111),
        borderRadius: BorderRadius.circular(DesignTokens.radius2xl + 6),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Stack(
        children: [
          SizedBox(height: 200, child: CustomPaint(painter: _HrGraphPainter(points: points), size: Size.infinite)),
          Positioned.fill(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                RichText(
                  text: TextSpan(
                    style: DesignTokens.titleFont(fontSize: 52, color: Colors.white, weight: FontWeight.w900, letterSpacing: -0.5),
                    children: [
                      TextSpan(text: '$heartRate'),
                      TextSpan(text: ' BPM', style: DesignTokens.bodyFont(fontSize: 18, weight: FontWeight.w500, color: Colors.white54)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(color: zoneBg, borderRadius: BorderRadius.circular(999)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PulseDot(color: zoneColor),
                      const SizedBox(width: 8),
                      Text(zoneLabel, style: DesignTokens.bodyFont(fontSize: 13, weight: FontWeight.w600, color: zoneColor)),
                    ],
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

class _HrGraphPainter extends CustomPainter {
  const _HrGraphPainter({required this.points});
  final List<double> points;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final midY = h * 0.4;

    Path fillArea(Path line) {
      final p = Path()..addPath(line, Offset.zero);
      p.lineTo(w, h);
      p.lineTo(0, h);
      p.close();
      return p;
    }

    Path buildLine() {
      final path = Path();
      for (var i = 0; i < points.length; i++) {
        final x = (i / (points.length - 1)) * w;
        final y = h - points[i] * h * 0.6 - midY;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          final px = ((i - 1) / (points.length - 1)) * w;
          final py = h - points[i - 1] * h * 0.6 - midY;
          final cx = (px + x) / 2;
          path.cubicTo(cx, py, cx, y, x, y);
        }
      }
      return path;
    }

    final line = buildLine();
    // Glow underlay
    final glow = Paint()
      ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [
        Color(0x4022D3EE), Color(0x1422D3EE), Colors.transparent
      ]).createShader(Offset.zero & size);
    canvas.drawPath(fillArea(line), glow);

    // Stroke
    canvas.drawPath(
      line,
      Paint()
        ..shader = DesignTokens.focusHrGradient.createShader(Offset.zero & size)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_HrGraphPainter old) => old.points != points;
}

class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color});
  final Color color;
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
        scale: Tween(begin: 0.8, end: 1.4).animate(_c),
        child: Container(width: 8, height: 8, decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle)),
      );
}

/* ─────────────────────── Exercise inputs ─────────────────────── */

class _ExerciseInputs extends StatelessWidget {
  const _ExerciseInputs({
    required this.weight,
    required this.reps,
    required this.rpe,
    required this.onWeight,
    required this.onReps,
    required this.onRpe,
  });
  final double weight;
  final int reps;
  final double rpe;
  final void Function(double) onWeight;
  final void Function(double) onReps;
  final void Function(double) onRpe;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _InputTile(label: 'Peso', value: weight, step: 0.5, unit: 'kg', onChange: onWeight, display: (v) => v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1))),
        const SizedBox(width: 12),
        Expanded(child: _InputTile(label: 'Reps', value: reps.toDouble(), step: 1, unit: '', onChange: (v) => onReps(v), display: (v) => v.round().toString())),
        const SizedBox(width: 12),
        Expanded(child: _InputTile(label: 'RPE', value: rpe, step: 0.5, unit: '', onChange: onRpe, display: (v) => v.toStringAsFixed(1))),
      ],
    );
  }
}

class _InputTile extends StatelessWidget {
  const _InputTile({
    required this.label,
    required this.value,
    required this.step,
    required this.unit,
    required this.onChange,
    required this.display,
  });
  final String label;
  final double value;
  final double step;
  final String unit;
  final void Function(double) onChange;
  final String Function(double) display;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x99111111),
        borderRadius: BorderRadius.circular(DesignTokens.radius2xl + 6),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          Text(label.toUpperCase(),
              style: DesignTokens.bodyFont(fontSize: 11, weight: FontWeight.w600, color: Colors.white54, letterSpacing: 2)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StepperButton(icon: LucideIcons.minus, onTap: () => onChange(value - step)),
              const SizedBox(width: 12),
              Column(
                children: [
                  Text(display(value),
                      style: DesignTokens.titleFont(fontSize: 28, color: Colors.white, weight: FontWeight.bold, letterSpacing: -0.5)),
                  if (unit.isNotEmpty)
                    Text(unit, style: DesignTokens.bodyFont(fontSize: 12, weight: FontWeight.w500, color: Colors.white54)),
                ],
              ),
              const SizedBox(width: 12),
              _StepperButton(icon: LucideIcons.plus, onTap: () => onChange(value + step)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xCC2A2A2A),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 44, height: 44, child: Icon(icon, size: 20, color: Colors.white)),
        ),
      );
}

/* ─────────────────────── AI rest card ─────────────────────── */

class _AiRestCard extends StatelessWidget {
  const _AiRestCard({
    required this.restTime,
    required this.maxTime,
    required this.isResting,
    this.onVoice,
  });
  final int restTime;
  final int maxTime;
  final bool isResting;
  final VoidCallback? onVoice;

  @override
  Widget build(BuildContext context) {
    final progress = maxTime == 0 ? 0.0 : (restTime / maxTime).clamp(0.0, 1.0);
    final mm = (restTime / 60).floor();
    final ss = restTime % 60;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0x99111111),
        borderRadius: BorderRadius.circular(DesignTokens.radius2xl + 6),
        border: Border.all(color: const Color(0x33818CF8)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 68,
            height: 68,
            child: Stack(
              children: [
                CustomPaint(painter: _RestRing(progress: progress)),
                const Center(child: Icon(LucideIcons.sparkles, size: 24, color: Color(0xFF818CF8))),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${mm.toString().padLeft(2, '0')}:${ss.toString().padLeft(2, '0')}',
                    style: DesignTokens.titleFont(fontSize: 20, color: Colors.white, weight: FontWeight.bold, letterSpacing: -0.5)),
                Text(isResting ? 'Descanso óptimo' : 'Descanso completo',
                    style: DesignTokens.bodyFont(fontSize: 13, color: Colors.white54)),
              ],
            ),
          ),
          _VoiceFab(onTap: onVoice),
        ],
      ),
    );
  }
}

class _RestRing extends CustomPainter {
  const _RestRing({required this.progress});
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = 4.0;
    final r = (size.shortestSide / 2) - stroke / 2;
    final c = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(c, r, Paint()..color = Colors.white.withOpacity(0.08)..style = PaintingStyle.stroke..strokeWidth = stroke);
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..shader = DesignTokens.restGradient.createShader(Offset.zero & size)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = stroke,
      );
    }
  }

  @override
  bool shouldRepaint(_RestRing old) => old.progress != progress;
}

class _VoiceFab extends StatelessWidget {
  const _VoiceFab({this.onTap});
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.bottomLeft,
            end: Alignment.topRight,
            colors: [Color(0xFF7C3AED), Color(0xFF6366F1), Color(0xFF06B6D4)],
          ),
          boxShadow: [BoxShadow(color: Color(0x806366F1), blurRadius: 16, spreadRadius: -2)],
        ),
        child: const Icon(LucideIcons.mic, size: 24, color: Colors.white),
      ),
    );
  }
}

/* ─────────────────────── Complete set CTA ─────────────────────── */

class _CompleteSetButton extends StatelessWidget {
  const _CompleteSetButton({this.onTap});
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        height: 64,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          boxShadow: const [BoxShadow(color: Color(0x26FFFFFF), blurRadius: 40, spreadRadius: 0)],
        ),
        child: Text('Completar Serie',
            style: DesignTokens.titleFont(fontSize: 18, color: Colors.black, weight: FontWeight.w600, letterSpacing: -0.3)),
      ),
    );
  }
}