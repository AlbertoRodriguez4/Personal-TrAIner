import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../services/health_service.dart';

/// Pantalla de Recuperación & Sueño IA — réplica de `recovery.tsx`.
///
/// Carga sus propios datos de sueño desde Health Connect al abrir la pantalla.
class RecoveryPage extends StatefulWidget {
  const RecoveryPage({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<RecoveryPage> createState() => _RecoveryPageState();
}

class _RecoveryPageState extends State<RecoveryPage> {
  ReadinessSummary? _r;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      await HealthService.requestPermissions();
      _r = await HealthService.fetchSleepAndReadiness();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;

    if (_loading) {
      return Scaffold(
        backgroundColor: DesignTokens.background(b),
        body: const SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: DesignTokens.background(b),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Error: $_error',
                      textAlign: TextAlign.center,
                      style: DesignTokens.bodyFont(
                          fontSize: 14, color: DesignTokens.foreground(b))),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _load, child: const Text('Reintentar')),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // ── Estados vacíos diferenciados para QA ──
    final String totalSleep;
    final String remSleep;
    final String restingHr;
    final String heroBody;
    final String alertText;
    final String totalBed;

    if (_r == null) {
      // Sin datos (permisos o HC no disponible)
      totalSleep = 'Sin datos';
      remSleep   = 'Sin datos';
      restingHr  = 'Sin datos';
      heroBody   = 'Sin datos de sueño esta noche. Conecta tu wearable y verifica los permisos de Health Connect.';
      alertText  = 'Sin análisis predictivo disponible.';
      totalBed   = 'Sin datos';
    } else if (_r!.sleepMinutes == 0) {
      // HC respondió pero no hay registros de sueño en la ventana
      totalSleep = 'Sin registros';
      remSleep   = _r!.remSleepLabel;
      restingHr  = _r!.restingHrLabel;
      heroBody   = 'Sin registros de sueño en la ventana nocturna. Verifica que Mi Fitness sincroniza sueño a Health Connect.';
      alertText  = _r!.alertBody;
      totalBed   = 'Sin registros';
    } else {
      totalSleep = _r!.totalSleepLabel;
      remSleep   = _r!.remSleepLabel;
      restingHr  = _r!.restingHrLabel;
      heroBody   = _r!.alertBody;
      alertText  = _r!.alertBody;
      totalBed   = _r!.totalSleepLabel;
    }

    // Construir fases del sueño como pct de la barra apilada.
    final stageMin = _r?.stageMinutes ?? const <String, int>{};
    final total = (stageMin['deep'] ?? 0) +
                  (stageMin['rem']  ?? 0) +
                  (stageMin['light'] ?? 0) +
                  (stageMin['awake'] ?? 0);
    double pctOf(int v) => total > 0 ? (v / total) * 100 : 0.0;
    final stages = <SleepStage>[
      SleepStage(label: 'Profundo',  pct: pctOf(stageMin['deep']  ?? 0), color: DesignTokens.recoveryGlassFrom),
      SleepStage(label: 'REM',       pct: pctOf(stageMin['rem']   ?? 0), color: DesignTokens.recoveryAlertFrom),
      SleepStage(label: 'Ligero',    pct: pctOf(stageMin['light'] ?? 0), color: DesignTokens.recoveryAlertTo),
      SleepStage(label: 'Despierto', pct: pctOf(stageMin['awake'] ?? 0), color: const Color(0xFF3A3F4D)),
    ];

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
                _TopBar(title: 'Recuperación IA', onBack: widget.onBack),
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
                  hrvDeltaPercent: 0,
                ),
                if (_r == null) ...[
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _load,
                    icon: const Icon(LucideIcons.refreshCw, size: 16),
                    label: const Text('Recargar'),
                  ),
                ],
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