import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/theme/design_tokens.dart';

/// Tour de bienvenida de 3 pasos, previo al registro.
///
/// No confundir con `OnboardingPage`: aquélla es el asistente que RECOGE datos
/// del perfil una vez ya hay cuenta. Éste solo explica qué hace la app antes de
/// pedir nada, y termina llevando a la pantalla de login/registro.
///
/// Vive en claro siempre, ignorando el tema del sistema: es una pantalla de
/// presentación con fondo ilustrado propio, y en oscuro las ilustraciones
/// (orbes difuminados, rejilla tenue) pierden todo el contraste.
class TourPage extends StatefulWidget {
  const TourPage({super.key});

  @override
  State<TourPage> createState() => _TourPageState();
}

class _TourPageState extends State<TourPage> {
  int _step = 0;

  static const _bg = Color(0xFFF5F5F7);
  static const _ink = Color(0xFF1D1D1F);
  static const _inkMuted = Color(0xFF6E6E73);

  static const _steps = <_TourStep>[
    _TourStep(
      eyebrow: '01 · Dispositivos',
      titleStart: 'Tu cuerpo, ',
      titleAccent: 'en vivo.',
      body:
          'Conecta por Bluetooth tu banda de frecuencia cardíaca o smartwatch '
          '(Xiaomi, Redmi, Polar, Garmin…) para leer tu biometría en tiempo '
          'real durante cada entrenamiento.',
      accent: Color(0xFF22D3EE),
      accentTo: Color(0xFF6366F1),
      bullets: [
        (LucideIcons.bluetooth, 'Emparejado seguro BLE'),
        (LucideIcons.heartPulse, 'FC en directo · latido a latido'),
        (LucideIcons.activity, 'Zonas de esfuerzo dinámicas'),
      ],
    ),
    _TourStep(
      eyebrow: '02 · Health Connect',
      titleStart: 'Tu historial es el ',
      titleAccent: 'combustible.',
      body:
          'Sincronizamos pasos, entrenamientos, calorías, distancia y sueño '
          'desde Health Connect. Un único hilo de datos que alimenta a tu IA '
          'para entender tu forma real.',
      accent: Color(0xFFA3E635),
      accentTo: Color(0xFF10B981),
      bullets: [
        (LucideIcons.footprints, 'Pasos · distancia · cardio'),
        (LucideIcons.flame, 'Calorías activas y basales'),
        (LucideIcons.moon, 'Fases y calidad del sueño'),
      ],
    ),
    _TourStep(
      eyebrow: '03 · IA Personal',
      titleStart: 'Un coach que ',
      titleAccent: 'te entiende.',
      body:
          'Con tus datos históricos y en tiempo real, la IA ajusta rutinas, '
          'evalúa recuperación y protege tu salud. Nada sale de tu bóveda '
          'cifrada sin tu permiso.',
      accent: Color(0xFFC084FC),
      accentTo: Color(0xFF22D3EE),
      bullets: [
        (LucideIcons.brain, 'Rutinas adaptativas diarias'),
        (LucideIcons.sparkles, 'Recuperación y RPE inteligentes'),
        (LucideIcons.shieldCheck, 'Privacidad cifrada · tú mandas'),
      ],
    ),
  ];

  void _goToAuth() =>
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);

  void _next() {
    if (_step < _steps.length - 1) {
      setState(() => _step++);
    } else {
      _goToAuth();
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_step];
    final isLast = _step == _steps.length - 1;

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // Capa decorativa: rejilla tenue + orbe difuminado teñido del paso.
          Positioned.fill(
            child: CustomPaint(painter: _AmbientPainter(accent: step.accent)),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  children: [
                    _buildHeader(),
                    _buildProgress(),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 320),
                          child: Column(
                            key: ValueKey(_step),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                height: 230,
                                child: _StepVisual(step: _step, accent: step.accent),
                              ),
                              const SizedBox(height: 24),
                              Text(step.eyebrow,
                                  style: DesignTokens.labelSmall(color: _inkMuted)),
                              const SizedBox(height: 8),
                              RichText(
                                text: TextSpan(
                                  style: DesignTokens.titleFont(
                                      fontSize: 30, color: _ink, height: 1.15),
                                  children: [
                                    TextSpan(text: step.titleStart),
                                    TextSpan(
                                      text: step.titleAccent,
                                      style: TextStyle(color: step.accent),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(step.body,
                                  style: DesignTokens.bodyFont(
                                      fontSize: 14.5,
                                      color: _inkMuted,
                                      height: 1.55)),
                              const SizedBox(height: 20),
                              for (final bullet in step.bullets) ...[
                                _BulletRow(
                                  icon: bullet.$1,
                                  label: bullet.$2,
                                  accent: step.accent,
                                ),
                                const SizedBox(height: 8),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    _buildFooter(step, isLast),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Row(
        children: [
          Text('Personal Tr', style: DesignTokens.bodyFont(fontSize: 14, weight: FontWeight.w700, color: _ink)),
          ShaderMask(
            shaderCallback: (bounds) =>
                DesignTokens.aiGradient.createShader(bounds),
            child: Text('AI',
                style: DesignTokens.bodyFont(
                    fontSize: 14, weight: FontWeight.w800, color: Colors.white)),
          ),
          Text('ner', style: DesignTokens.bodyFont(fontSize: 14, weight: FontWeight.w700, color: _ink)),
          const Spacer(),
          TextButton(
            onPressed: _goToAuth,
            child: Text('Saltar',
                style: DesignTokens.bodyFont(
                    fontSize: 13, weight: FontWeight.w600, color: _inkMuted)),
          ),
        ],
      ),
    );
  }

  /// Segmentos tocables: permiten saltar directo a un paso concreto, no solo
  /// avanzar. Cada uno se tiñe con el acento de SU paso, no el del actual.
  Widget _buildProgress() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Row(
        children: [
          for (var i = 0; i < _steps.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: Semantics(
                button: true,
                label: 'Ir al paso ${i + 1}',
                child: InkWell(
                  onTap: () => setState(() => _step = i),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: i <= _step
                          ? _steps[i].accent
                          : _ink.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter(_TourStep step, bool isLast) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: Column(
        children: [
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: _next,
              borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
              child: Ink(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [step.accent, step.accentTo],
                  ),
                  borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
                ),
                child: Center(
                  child: Text(
                    isLast ? 'Empezar a sincronizar' : 'Continuar',
                    style: DesignTokens.bodyFont(
                        fontSize: 15, weight: FontWeight.w700, color: _ink),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (_step == 0)
            Text('Al continuar aceptas nuestros Términos y Privacidad.',
                textAlign: TextAlign.center,
                style: DesignTokens.bodyFont(fontSize: 11.5, color: _inkMuted))
          else
            TextButton(
              onPressed: () => setState(() => _step--),
              child: Text('Atrás',
                  style: DesignTokens.bodyFont(
                      fontSize: 13, weight: FontWeight.w600, color: _inkMuted)),
            ),
        ],
      ),
    );
  }
}

class _TourStep {
  const _TourStep({
    required this.eyebrow,
    required this.titleStart,
    required this.titleAccent,
    required this.body,
    required this.accent,
    required this.accentTo,
    required this.bullets,
  });

  final String eyebrow;
  final String titleStart;
  final String titleAccent;
  final String body;
  final Color accent;
  final Color accentTo;
  final List<(IconData, String)> bullets;
}

class _BulletRow extends StatelessWidget {
  const _BulletRow({
    required this.icon,
    required this.label,
    required this.accent,
  });
  final IconData icon;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
        border: Border.all(color: const Color(0x141D1D1F)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
            ),
            child: Icon(icon, size: 16, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: DesignTokens.bodyFont(
                    fontSize: 13.5,
                    weight: FontWeight.w600,
                    color: _TourPageState._ink)),
          ),
          Icon(LucideIcons.check,
              size: 15, color: _TourPageState._ink.withOpacity(0.25)),
        ],
      ),
    );
  }
}

/// Fondo ambiental: rejilla fina + orbe difuminado teñido por el paso actual.
class _AmbientPainter extends CustomPainter {
  const _AmbientPainter({required this.accent});
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    const cell = 44.0;
    final grid = Paint()
      ..color = const Color(0xFF1D1D1F).withOpacity(0.035)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += cell) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y < size.height; y += cell) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final center = Offset(size.width * 0.5, size.height * 0.22);
    canvas.drawCircle(
      center,
      size.width * 0.62,
      Paint()
        ..shader = RadialGradient(
          colors: [accent.withOpacity(0.22), accent.withOpacity(0)],
        ).createShader(Rect.fromCircle(center: center, radius: size.width * 0.62)),
    );
  }

  @override
  bool shouldRepaint(_AmbientPainter old) => old.accent != accent;
}

/// Ilustración por paso. Las tres se animan con un único controlador cíclico.
class _StepVisual extends StatefulWidget {
  const _StepVisual({required this.step, required this.accent});
  final int step;
  final Color accent;

  @override
  State<_StepVisual> createState() => _StepVisualState();
}

class _StepVisualState extends State<_StepVisual>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );

  @override
  void initState() {
    super.initState();
    if (!WidgetsBinding
        .instance.platformDispatcher.accessibilityFeatures.reduceMotion) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        switch (widget.step) {
          case 0:
            return _WatchVisual(t: _c.value, accent: widget.accent);
          case 1:
            return _StatsVisual(t: _c.value, accent: widget.accent);
          default:
            return _OrbitVisual(t: _c.value, accent: widget.accent);
        }
      },
    );
  }
}

/// Paso 1: reloj con anillos de radar expandiéndose y FC en vivo.
class _WatchVisual extends StatelessWidget {
  const _WatchVisual({required this.t, required this.accent});
  final double t;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        CustomPaint(
          size: const Size(230, 230),
          painter: _RadarPainter(t: t, accent: accent),
        ),
        // Cuerpo del reloj: rectángulo redondeado con las dos pestañas.
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 26,
              height: 12,
              decoration: BoxDecoration(
                color: const Color(0xFF2B2B30),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Container(
              width: 96,
              height: 118,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF17171B),
                borderRadius: BorderRadius.circular(26),
                boxShadow: const [
                  BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 6)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.scale(
                    scale: 1 + 0.12 * math.sin(t * 2 * math.pi),
                    child: Icon(LucideIcons.heartPulse, size: 22, color: accent),
                  ),
                  const SizedBox(height: 6),
                  Text('142',
                      style: DesignTokens.titleFont(
                          fontSize: 26, color: Colors.white)),
                  Text('bpm',
                      style: DesignTokens.bodyFont(
                          fontSize: 10, color: Colors.white54)),
                ],
              ),
            ),
            Container(
              width: 26,
              height: 12,
              decoration: BoxDecoration(
                color: const Color(0xFF2B2B30),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
        Positioned(top: 6, right: 4, child: _FloatingPill(text: 'Bluetooth · Live', accent: accent)),
        const Positioned(bottom: 10, left: 0, child: _FloatingPill(text: 'Redmi Watch 5')),
      ],
    );
  }
}

class _FloatingPill extends StatelessWidget {
  const _FloatingPill({required this.text, this.accent});
  final String text;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (accent != null) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(text,
              style: DesignTokens.bodyFont(
                  fontSize: 11,
                  weight: FontWeight.w600,
                  color: _TourPageState._ink)),
        ],
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  const _RadarPainter({required this.t, required this.accent});
  final double t;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // Tres anillos desfasados 1/3 de ciclo: siempre hay uno saliendo.
    for (var i = 0; i < 3; i++) {
      final phase = (t + i / 3) % 1.0;
      final radius = 45 + phase * 70;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = accent.withOpacity((1 - phase) * 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.t != t || old.accent != accent;
}

/// Paso 2: rejilla 2×2 de métricas con punto "en vivo" pulsante.
class _StatsVisual extends StatelessWidget {
  const _StatsVisual({required this.t, required this.accent});
  final double t;
  final Color accent;

  static const _stats = [
    ('8 420', 'pasos'),
    ('612', 'kcal'),
    ("42'", 'cardio'),
    ('7h 12', 'sueño'),
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 260,
        child: GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.6,
          children: [
            for (var i = 0; i < _stats.length; i++)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
                  boxShadow: const [
                    BoxShadow(color: Color(0x12000000), blurRadius: 12, offset: Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Opacity(
                          // Cada tarjeta late desfasada para que la rejilla
                          // parezca viva en vez de parpadear al unísono.
                          opacity: 0.35 +
                              0.65 *
                                  (0.5 +
                                      0.5 *
                                          math.sin(
                                              (t + i * 0.18) * 2 * math.pi)),
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                                color: accent, shape: BoxShape.circle),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(_stats[i].$2,
                            style: DesignTokens.bodyFont(
                                fontSize: 10.5,
                                color: _TourPageState._inkMuted)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(_stats[i].$1,
                        style: DesignTokens.titleFont(
                            fontSize: 20, color: _TourPageState._ink)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Paso 3: tres órbitas concéntricas girando a distinta velocidad.
class _OrbitVisual extends StatelessWidget {
  const _OrbitVisual({required this.t, required this.accent});
  final double t;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        CustomPaint(
          size: const Size(230, 230),
          painter: _OrbitPainter(t: t, accent: accent),
        ),
        Container(
          width: 68,
          height: 68,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: DesignTokens.aiGradient,
            boxShadow: [
              BoxShadow(color: accent.withOpacity(0.45), blurRadius: 26, spreadRadius: 2),
            ],
          ),
          child: const Icon(LucideIcons.sparkles, size: 28, color: Colors.white),
        ),
      ],
    );
  }
}

class _OrbitPainter extends CustomPainter {
  const _OrbitPainter({required this.t, required this.accent});
  final double t;
  final Color accent;

  static const _radii = [52.0, 78.0, 104.0];
  static const _speeds = [1.0, -0.62, 0.4];
  static const _dotColors = [
    Color(0xFF22D3EE),
    Color(0xFFC084FC),
    Color(0xFFF0ABFC),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    for (var i = 0; i < _radii.length; i++) {
      canvas.drawCircle(
        center,
        _radii[i],
        Paint()
          ..color = accent.withOpacity(0.18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );

      final angle = t * 2 * math.pi * _speeds[i];
      final dot = Offset(
        center.dx + _radii[i] * math.cos(angle),
        center.dy + _radii[i] * math.sin(angle),
      );
      canvas.drawCircle(dot, 9, Paint()..color = _dotColors[i].withOpacity(0.25));
      canvas.drawCircle(dot, 4.5, Paint()..color = _dotColors[i]);
    }
  }

  @override
  bool shouldRepaint(_OrbitPainter old) => old.t != t || old.accent != accent;
}
