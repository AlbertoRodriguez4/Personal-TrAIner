import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/theme/design_tokens.dart';

/// Pantalla de Recuperación & Sueño IA — réplica de `recovery.tsx`.
///
/// Todas las métricas (fases de sueño, HR en reposo, alerta IA, VFC) se inyectan
/// por constructor para no hardcodear mocks.
class RecoveryPage extends StatelessWidget {
  const RecoveryPage({
    super.key,
    required this.totalSleep,
    required this.remSleep,
    required this.restingHr,
    required this.totalBed,
    required this.stages,
    required this.hrvDeltaPercent,
    required this.alertText,
    required this.heroBody,
    this.onBack,
  });

  /// Ej: "6h 15m"
  final String totalSleep;
  final String remSleep;
  /// Ej: "52 bpm"
  final String restingHr;
  /// Ej: "7h 25m en cama"
  final String totalBed;

  /// Fases del sueño (profundo / REM / ligero / despierto) — datos inyectados.
  // TODO: conectar a GET /recovery/sleep/{date} (NestJS) → fases desde Mi Fitness/Health Connect.
  final List<SleepStage> stages;

  /// Delta VFC nocturno vs media semanal (ej: 8 → "+8%").
  final int hrvDeltaPercent;

  /// Texto de la alerta predictiva de IA (oración del modelo).
  // TODO: conectar a GET /recovery/predictive-alert (FastAPI).
  final String alertText;

  /// Cuerpo del hero glass card (acción recalibrada por la IA).
  final String heroBody;

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Scaffold(
      backgroundColor: DesignTokens.background(b),
      body: SafeArea(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TopBar(title: 'Recuperación IA', onBack: onBack),
                const SizedBox(height: 20),
                _HeroGlassCard(body: heroBody),
                const SizedBox(height: 20),
                _PredictiveAlert(text: alertText),
                const SizedBox(height: 20),
                _StatPillsRow(
                  totalSleep: totalSleep,
                  remSleep: remSleep,
                  restingHr: restingHr,
                ),
                const SizedBox(height: 20),
                _SleepStagesCard(
                  totalBed: totalBed,
                  stages: stages,
                  hrvDeltaPercent: hrvDeltaPercent,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/* ─────────────────────── Top bar ─────────────────────── */

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, this.onBack});
  final String title;
  final VoidCallback? onBack;
  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
      child: Row(
        children: [
          _RoundIconButton(icon: LucideIcons.arrowLeft, onTap: onBack ?? () => Navigator.maybePop(context)),
          const SizedBox(width: 12),
          Text(title.toUpperCase(), style: DesignTokens.labelSmall(color: DesignTokens.mutedForeground(b))),
        ],
      ),
    );
  }
}

/* ─────────────────────── Hero glass ─────────────────────── */

class _HeroGlassCard extends StatelessWidget {
  const _HeroGlassCard({required this.body});
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: DesignTokens.recoveryHeroGradient,
        borderRadius: BorderRadius.circular(DesignTokens.cardRadius),
        boxShadow: const [
          BoxShadow(color: Color(0x596A5CF0), blurRadius: 32, spreadRadius: -16, offset: Offset(0, 8)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -48,
            top: -48,
            child: IgnorePointer(
              child: Container(
                width: 176,
                height: 176,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: DesignTokens.aiGradient,
                ),
              ),
            ),
          ),
          // El blur del prototipo se aproxima con opacity; en Flutter real se
          // usaría ImageFilter.blur. Mantenemos simple para evitar-dependencias.
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(DesignTokens.cardRadius),
              child: Container(
                color: Colors.white.withOpacity(0.0),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(shape: BoxShape.circle, gradient: DesignTokens.aiGradient),
                    child: const Icon(LucideIcons.sparkles, size: 16, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Text('Sueño · Esta noche'.toUpperCase(),
                      style: DesignTokens.labelSmall(color: DesignTokens.recoveryAlertText.withOpacity(0.85))),
                ],
              ),
              const SizedBox(height: 12),
              ShaderMask(
                shaderCallback: (bounds) => DesignTokens.aiGradient.createShader(Offset.zero & bounds.size),
                blendMode: BlendMode.srcIn,
                child: Text('Análisis de Recuperación',
                    style: DesignTokens.titleFont(fontSize: 26, height: 1.15, color: Colors.white)),
              ),
              const SizedBox(height: 8),
              Text(body, style: DesignTokens.bodyFont(fontSize: 13, color: DesignTokens.recoveryAlertText, height: 1.4)),
            ],
          ),
        ],
      ),
    );
  }
}

/* ─────────────────────── Predictive alert ─────────────────────── */

class _PredictiveAlert extends StatelessWidget {
  const _PredictiveAlert({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: DesignTokens.recoveryAlertGradient,
        borderRadius: BorderRadius.circular(DesignTokens.cardRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.6), shape: BoxShape.circle),
            child: Icon(LucideIcons.alertTriangle, size: 16, color: DesignTokens.recoveryAlertIcon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Alerta predictiva · IA'.toUpperCase(),
                    style: DesignTokens.labelSmall(color: DesignTokens.recoveryAlertText.withOpacity(0.85))),
                const SizedBox(height: 6),
                Text(text,
                    style: DesignTokens.bodyFont(
                        fontSize: 14, weight: FontWeight.w600, color: DesignTokens.recoveryAlertText, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ─────────────────────── Stat pills ─────────────────────── */

class _StatPillsRow extends StatelessWidget {
  const _StatPillsRow({required this.totalSleep, required this.remSleep, required this.restingHr});
  final String totalSleep, remSleep, restingHr;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final stats = [
      (icon: LucideIcons.moon, label: 'Total Sleep', value: totalSleep),
      (icon: LucideIcons.sparkles, label: 'REM', value: remSleep),
      (icon: LucideIcons.heart, label: 'Resting HR', value: restingHr),
    ];
    return Row(
      children: [
        for (final s in stats) ...[
          if (s != stats.first) const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: DesignTokens.surface1(b),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(s.icon, size: 14, color: DesignTokens.mutedForeground(b)),
                  const SizedBox(height: 8),
                  Text(s.label.toUpperCase(), style: DesignTokens.labelSmall(color: DesignTokens.mutedForeground(b), fontSize: 9)),
                  const SizedBox(height: 4),
                  Text(s.value, style: DesignTokens.bodyFont(fontSize: 13, weight: FontWeight.w700, color: DesignTokens.foreground(b), height: 1.1)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/* ─────────────────────── Sleep stages ─────────────────────── */

/// Fases del sueño como gráfico equivalente al de React:
/// barra apilada horizontal + leyenda 2 columnas — equivalente al de barras
/// apiladas del prototipo (no circular, igual que en `recovery.tsx`).
class _SleepStagesCard extends StatelessWidget {
  const _SleepStagesCard({required this.totalBed, required this.stages, required this.hrvDeltaPercent});
  final String totalBed;
  final List<SleepStage> stages;
  final int hrvDeltaPercent;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DesignTokens.card(b),
        borderRadius: BorderRadius.circular(DesignTokens.cardRadius),
        boxShadow: DesignTokens.shadowSoft(b),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Fases del sueño'.toUpperCase(), style: DesignTokens.labelSmall(color: DesignTokens.mutedForeground(b))),
              const Spacer(),
              Text(totalBed, style: DesignTokens.bodyFont(fontSize: 11, color: DesignTokens.mutedForeground(b))),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  for (var i = 0; i < stages.length; i++)
                    Expanded(
                      flex: (stages[i].pct).round().clamp(1, 9999),
                      child: Container(color: stages[i].color),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 6,
            mainAxisSpacing: 10,
            crossAxisSpacing: 16,
            children: [
              for (final s in stages)
                Row(
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text(s.label, style: DesignTokens.bodyFont(fontSize: 12, color: DesignTokens.foreground(b))),
                    const Spacer(),
                    Text('${s.pct.round()}%',
                        style: DesignTokens.bodyFont(fontSize: 12, weight: FontWeight.w700, color: DesignTokens.foreground(b))),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: DesignTokens.surface1(b),
              borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.activity, size: 16, color: DesignTokens.aiTo),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: DesignTokens.bodyFont(fontSize: 12, color: DesignTokens.foreground(b)),
                      children: [
                        const TextSpan(text: 'VFC nocturna '),
                        TextSpan(text: '${hrvDeltaPercent >= 0 ? '+' : ''}$hrvDeltaPercent%',
                            style: DesignTokens.bodyFont(fontSize: 12, weight: FontWeight.w700, color: DesignTokens.foreground(b))),
                        const TextSpan(text: ' vs media semanal.'),
                      ],
                    ),
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

/* ─────────────────────── Model + helpers ─────────────────────── */

@immutable
class SleepStage {
  const SleepStage({required this.label, required this.pct, required this.color});
  final String label;
  final double pct;
  final Color color;
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: DesignTokens.surface1(b), shape: BoxShape.circle),
        child: Icon(icon, size: 16, color: DesignTokens.foreground(b)),
      ),
    );
  }
}