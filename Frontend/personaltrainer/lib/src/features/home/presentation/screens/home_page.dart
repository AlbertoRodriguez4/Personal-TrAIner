import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:health/health.dart';

import '../../../../services/health_service.dart';
import '../../../../core/providers/theme_provider.dart';

import '../../../../core/providers/routine_provider.dart';
import '../../../../core/providers/daily_summary_provider.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/ui/ai_animations.dart';
import '../../../../core/ui/ai_gradient_text.dart';
import '../../../../core/ui/glass_card.dart';
import '../../../../core/ui/metric_ring.dart';
import '../../../../services/api_service.dart';
import '../../../ai_coach/presentation/screens/ai_coach_page.dart';
import '../../../routine/presentation/screens/routines_home_page.dart';
import '../../models/daily_summary.dart';
import 'backend_features_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.onSessionClosed});

  final VoidCallback? onSessionClosed;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _tab = 'dashboard';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RoutineProvider>().loadRoutines();
      context.read<DailySummaryProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final bg = DesignTokens.background(b);
    final routines = context.watch<RoutineProvider>().routines;

    return Scaffold(
      backgroundColor: DesignTokens.surface2of(b),
      body: SafeArea(
        child: Container(
          color: bg,
          child: Column(
            children: [
              _Header(),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _buildScreen(routines),
                ),
              ),
              _BottomNav(
                active: _tab,
                onChange: (k) => setState(() => _tab = k),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScreen(List routines) {
    switch (_tab) {
      case 'coach':
        return _CoachScreen(onOpen: () => _openAiCoach(context));
      case 'nutrition':
        return _NutritionScreen(onOpen: () => _openBackend(context));
      case 'clinic':
        return _ClinicScreen(onOpen: () => _openBackend(context));
      default:
        return _DashboardScreen(
          routinesCount: routines.length,
          onOpenRoutines: _openRoutines,
          onOpenAiCoach: _openAiCoach,
          onOpenBackend: _openBackend,
          onLogout: _logout,
        );
    }
  }

  Future<void> _logout(BuildContext context) async {
    await ApiService.logout();
    widget.onSessionClosed?.call();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
  }

  void _openRoutines(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const RoutinesHomePage()),
      );

  void _openAiCoach(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AiCoachPage()),
      );

  void _openBackend(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const BackendFeaturesPage()),
      );
}

/* ============================== HEADER ============================== */

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    final meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    final fecha = '${dias[now.weekday - 1]} · ${now.day} ${meses[now.month - 1]}';
    final mutedFg = DesignTokens.mutedForeground(Theme.of(context).brightness);
    final fg = DesignTokens.foreground(Theme.of(context).brightness);

    return GlassCard(
      radius: 0,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      shadow: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fecha.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.4,
                    color: mutedFg,
                  ),
                ),
                const SizedBox(height: 2),
                RichText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: fg,
                    ),
                    children: const [
                      TextSpan(text: 'Personal Tr'),
                      TextSpan(text: 'AI', style: TextStyle(fontStyle: FontStyle.italic)),
                      TextSpan(text: 'ner'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: () => context.read<ThemeProvider>().toggleTheme(context),
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? PhosphorIcons.sun()
                  : PhosphorIcons.moon(),
            ),
            color: fg,
          ),
          const SizedBox(width: 12),
          const _LiveSync(),
        ],
      ),
    );
  }
}

class _LiveSync extends StatelessWidget {
  const _LiveSync();

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final fg = DesignTokens.foreground(b);
    final mutedFg = DesignTokens.mutedForeground(b);
    final surface1 = DesignTokens.surface1(b);
    final border = DesignTokens.border(b);
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: surface1,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const AiPulseEffect(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox(width: 8, height: 8),
                    ),
                  ),
                  AiRingEffect(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.4),
                        shape: BoxShape.circle,
                      ),
                      child: const SizedBox(width: 8, height: 8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(LucideIcons.heart, size: 14, color: fg.withOpacity(0.7)),
            const SizedBox(width: 4),
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: fg,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                children: [
                  const TextSpan(text: '64'),
                  TextSpan(
                    text: 'bpm',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: mutedFg,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ============================== DASHBOARD ============================== */

class _DashboardScreen extends StatelessWidget {
  const _DashboardScreen({
    required this.routinesCount,
    required this.onOpenRoutines,
    required this.onOpenAiCoach,
    required this.onOpenBackend,
    required this.onLogout,
  });

  final int routinesCount;
  final void Function(BuildContext) onOpenRoutines;
  final void Function(BuildContext) onOpenAiCoach;
  final void Function(BuildContext) onOpenBackend;
  final Future<void> Function(BuildContext) onLogout;

  @override
  Widget build(BuildContext context) {
    final userName = ApiService.getCurrentUserName() ?? 'Usuario';
    final firstName = userName.split(' ').first;
    final summaryProv = context.watch<DailySummaryProvider>();
    final summary = summaryProv.summary;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeroCard(firstName: firstName),
          const SizedBox(height: 16),
          _PredictiveAlert(),
          const SizedBox(height: 16),
          _QuickActions(
            onScan: () => onOpenBackend(context),
            onPosture: () => onOpenBackend(context),
            onUpload: () => onOpenBackend(context),
          ),
          const SizedBox(height: 16),
          _DailySummary(summary: summary, loading: summaryProv.isLoading, error: summaryProv.error),
          const SizedBox(height: 16),
          _WorkoutCard(
            routinesCount: summary?.rutinasCount ?? routinesCount,
            onTap: () => onOpenRoutines(context),
          ),
          const SizedBox(height: 16),
          _AiCard(onTalk: () => onOpenAiCoach(context)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => onLogout(context),
            icon: const Icon(LucideIcons.logOut, size: 18),
            label: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.firstName});
  final String firstName;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final fg = DesignTokens.foreground(b);
    final mutedFg = DesignTokens.mutedForeground(b);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: DesignTokens.aiGradientSoft,
        borderRadius: BorderRadius.circular(DesignTokens.cardRadius),
        boxShadow: DesignTokens.shadowCard(b),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hola, $firstName',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: fg,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Listo para entrenar con tu Coach IA hoy?',
                  style: TextStyle(fontSize: 14, color: mutedFg),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.asset(
              'assets/logo.jpg',
              height: 56,
              width: 56,
              fit: BoxFit.cover,
            ),
          ),
        ],
      ),
    );
  }
}

class _PredictiveAlert extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final fg = DesignTokens.foreground(b);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: DesignTokens.warnSoft,
        borderRadius: BorderRadius.circular(DesignTokens.cardRadius),
        boxShadow: DesignTokens.shadowCard(b),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.70),
              shape: BoxShape.circle,
              boxShadow: DesignTokens.shadowSoft(b),
            ),
            child: const Icon(LucideIcons.alertTriangle,
                size: 16, color: Color(0xFFC2410C)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ALERTA · TRANSFORMER IA',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.4,
                    color: const Color(0xFF9A3412).withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: fg,
                      height: 1.35,
                    ),
                    children: [
                      const TextSpan(text: 'Patrones de '),
                      TextSpan(text: 'VFC', style: TextStyle(fontWeight: FontWeight.w700)),
                      const TextSpan(text: ' indican fatiga sistémica. Carga de hoy '),
                      TextSpan(text: 'reducida un 20%', style: TextStyle(fontWeight: FontWeight.w700)),
                      const TextSpan(text: '.'),
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

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onScan,
    required this.onPosture,
    required this.onUpload,
  });

  final VoidCallback onScan;
  final VoidCallback onPosture;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Escanear', 'Comida', LucideIcons.camera, onScan),
      ('Evaluar', 'Postura', LucideIcons.scanLine, onPosture),
      ('Subir', 'Analítica', LucideIcons.fileText, onUpload),
    ];
    return Row(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          Expanded(child: _ActionTile(
            label: items[i].$1,
            sub: items[i].$2,
            icon: items[i].$3,
            onTap: items[i].$4,
          )),
          if (i < items.length - 1) const SizedBox(width: 12),
        ],
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.label,
    required this.sub,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String sub;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final card = DesignTokens.card(b);
    final fg = DesignTokens.foreground(b);
    final mutedFg = DesignTokens.mutedForeground(b);
    return Material(
      color: card,
      borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
            boxShadow: DesignTokens.shadowSoft(b),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: DesignTokens.aiGradientSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 16, color: fg),
              ),
              const SizedBox(height: 12),
              Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: fg)),
              Text(sub, style: TextStyle(fontSize: 11, color: mutedFg)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DailySummary extends StatelessWidget {
  const _DailySummary({required this.summary, required this.loading, required this.error});
  final DailySummary? summary;
  final bool loading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    if (loading || summary == null || error != null) {
      return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
    }
    final s = summary!;
    final b = Theme.of(context).brightness;
    final card = DesignTokens.card(b);
    final fg = DesignTokens.foreground(b);
    final mutedFg = DesignTokens.mutedForeground(b);
    final surface1 = DesignTokens.surface1(b);

    final pctK = (s.cumplKcal.porcentaje / 100).clamp(0.0, 1.0);
    
    // Falsos datos de carga física para igualar el mockup
    final pctCarga = 0.72;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Cuadrados superiores (Carga Física, Macros)
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
                  boxShadow: DesignTokens.shadowSoft(b),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CARGA FÍSICA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.0, color: mutedFg)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        MetricRing(value: '72', unit: '%', pct: pctCarga),
                        const SizedBox(width: 12),
                        Text('óptima', style: TextStyle(fontSize: 12, color: mutedFg)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
                  boxShadow: DesignTokens.shadowSoft(b),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('MACROS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.0, color: mutedFg)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        MetricRing(value: (s.consumidoHoy.kcal / 1000).toStringAsFixed(1), unit: 'k', pct: pctK),
                        const SizedBox(width: 12),
                        Text('kcal · ${(s.objetivos.kcal / 1000).toStringAsFixed(1)}k', style: TextStyle(fontSize: 12, color: mutedFg)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Macros Hoy
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(28),
            boxShadow: DesignTokens.shadowCard(b),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('MACROS · HOY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.4, color: mutedFg)),
                  Text('${s.consumidoHoy.kcal.toInt()} / ${s.objetivos.kcal.toInt()} kcal', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
                ],
              ),
              const SizedBox(height: 16),
              // Barra de progreso global
              Container(
                height: 8,
                decoration: BoxDecoration(color: DesignTokens.muted(b), borderRadius: BorderRadius.circular(999)),
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: pctK,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: DesignTokens.aiGradient,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Chips individuales
              Row(
                children: [
                  Expanded(
                    child: _MacroBox(
                      label: 'PROTEÍNA',
                      val: s.consumidoHoy.proteinasG.toInt(),
                      total: s.objetivos.proteinasG.toInt(),
                      color: const Color(0xFF9D7BFF),
                      surface1: surface1,
                      fg: fg,
                      mutedFg: mutedFg,
                      muted: DesignTokens.muted(b),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MacroBox(
                      label: 'CARBOHIDRATOS',
                      val: s.consumidoHoy.carbohidratosG.toInt(),
                      total: s.objetivos.carbohidratosG.toInt(),
                      color: const Color(0xFF06B6D4),
                      surface1: surface1,
                      fg: fg,
                      mutedFg: mutedFg,
                      muted: DesignTokens.muted(b),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MacroBox(
                      label: 'GRASAS',
                      val: s.consumidoHoy.grasasG.toInt(),
                      total: s.objetivos.grasasG.toInt(),
                      color: const Color(0xFFF87171),
                      surface1: surface1,
                      fg: fg,
                      mutedFg: mutedFg,
                      muted: DesignTokens.muted(b),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MacroBox extends StatelessWidget {
  const _MacroBox({
    required this.label,
    required this.val,
    required this.total,
    required this.color,
    required this.surface1,
    required this.fg,
    required this.mutedFg,
    required this.muted,
  });
  final String label;
  final int val;
  final int total;
  final Color color;
  final Color surface1;
  final Color fg;
  final Color mutedFg;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    double pct = total > 0 ? (val / total).clamp(0.0, 1.0) : 0.0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: surface1, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: mutedFg)),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: fg),
              children: [
                TextSpan(text: '$val'),
                TextSpan(text: '/${total}g', style: TextStyle(fontSize: 11, color: mutedFg, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 4,
            width: double.infinity,
            decoration: BoxDecoration(color: muted, borderRadius: BorderRadius.circular(999)),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: pct,
              child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999))),
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.a, required this.b});
  final Widget a;
  final Widget b;
  @override
  Widget build(BuildContext context) => Row(
        children: [Expanded(child: a), const SizedBox(width: 12), Expanded(child: b)],
      );
}

class _WorkoutCard extends StatelessWidget {
  const _WorkoutCard({required this.routinesCount, required this.onTap});
  final int routinesCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final card = DesignTokens.card(b);
    final fg = DesignTokens.foreground(b);
    final mutedFg = DesignTokens.mutedForeground(b);
    final surface1 = DesignTokens.surface1(b);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(28),
        boxShadow: DesignTokens.shadowCard(b),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ÚLTIMA ACTIVIDAD', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.4, color: mutedFg)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(999)),
                child: Row(
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFFFF6900), shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    const Text('XIAOMI', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Carrera al aire libre', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: fg)),
          const SizedBox(height: 4),
          Text('Hoy · 07:12', style: TextStyle(fontSize: 13, color: mutedFg, fontWeight: FontWeight.w500)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _StatPill(val: '38 min', sub: 'DURACIÓN', surface1: surface1, fg: fg, mutedFg: mutedFg)),
              const SizedBox(width: 8),
              Expanded(child: _StatPill(val: '152', sub: 'BPM MED', surface1: surface1, fg: fg, mutedFg: mutedFg)),
              const SizedBox(width: 8),
              Expanded(child: _StatPill(val: '412', sub: 'KCAL', surface1: surface1, fg: fg, mutedFg: mutedFg)),
              const SizedBox(width: 8),
              Expanded(child: _StatPill(val: '6.4 km', sub: 'DIST.', surface1: surface1, fg: fg, mutedFg: mutedFg)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.val, required this.sub, required this.surface1, required this.fg, required this.mutedFg});
  final String val;
  final String sub;
  final Color surface1;
  final Color fg;
  final Color mutedFg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(color: surface1, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Text(val, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: fg)),
          const SizedBox(height: 2),
          Text(sub, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: mutedFg)),
        ],
      ),
    );
  }
}

class _AiCard extends StatelessWidget {
  const _AiCard({required this.onTalk});
  final VoidCallback onTalk;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final fg = DesignTokens.foreground(b);
    final mutedFg = DesignTokens.mutedForeground(b);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: DesignTokens.card(b),
        borderRadius: BorderRadius.circular(28),
        boxShadow: DesignTokens.shadowCard(b),
      ),
      child: Stack(
        children: [
          // Fondo brillante AI 1
          Positioned(
            right: -64,
            top: -64,
            child: Container(
              width: 224,
              height: 224,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: DesignTokens.aiGradientSoft,
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: const SizedBox(),
              ),
            ),
          ),
          // Fondo brillante AI 2
          Positioned(
            left: -40,
            bottom: -80,
            child: Container(
              width: 192,
              height: 192,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: DesignTokens.aiGradientSoft,
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: const SizedBox(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: DesignTokens.aiGradient,
                        shape: BoxShape.circle,
                        boxShadow: DesignTokens.shadowSoft(b),
                      ),
                      child: const Icon(LucideIcons.sparkles, size: 14, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'TU IA · AHORA',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.4,
                        color: fg.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: fg, height: 1.35),
                    children: [
                      const TextSpan(text: 'Dormiste poco hoy. He adaptado tu rutina de fuerza para priorizar la '),
                      WidgetSpan(
                        child: AiGradientText(
                          'recuperación',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: fg),
                        ),
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: () {}, // Futura funcionalidad: Ver ajustes
                      child: Row(
                        children: [
                          Text(
                            'Ver ajustes',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: fg.withOpacity(0.8)),
                          ),
                          const SizedBox(width: 4),
                          Icon(LucideIcons.chevronRight, size: 16, color: fg.withOpacity(0.8)),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: onTalk,
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: fg,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: DesignTokens.shadowCard(b),
                        ),
                        child: Row(
                          children: [
                            Icon(LucideIcons.mic, size: 16, color: DesignTokens.background(b)),
                            const SizedBox(width: 8),
                            Text(
                              'Hablar con IA',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: DesignTokens.background(b),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ============================== COACH / ENTRENADOR ============================== */

class _CoachScreen extends StatelessWidget {
  const _CoachScreen({required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RagBubble(),
          const SizedBox(height: 16),
          _XiaomiWorkouts(),
          const SizedBox(height: 16),
          _VoiceHero(onTalk: onOpen),
          const SizedBox(height: 16),
          _FocusModeCard(),
        ],
      ),
    );
  }
}

class _RagBubble extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final fg = DesignTokens.foreground(b);
    final mutedFg = DesignTokens.mutedForeground(b);
    return Container(
      margin: const EdgeInsets.only(right: 40),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: DesignTokens.aiGradientSoft,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(24),
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: DesignTokens.shadowSoft(b),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  gradient: DesignTokens.aiGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.sparkles, size: 12, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text('MEMORIA CONTEXTUAL · RAG',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: mutedFg)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: fg, height: 1.35),
              children: [
                const TextSpan(text: 'Hola, noto por tu voz de ayer que estás estresado. He ajustado tu rutina de '),
                TextSpan(text: 'fuerza', style: TextStyle(fontWeight: FontWeight.w700)),
                const TextSpan(text: '.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VoiceHero extends StatelessWidget {
  const _VoiceHero({required this.onTalk});
  final VoidCallback onTalk;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final card = DesignTokens.card(b);
    final fg = DesignTokens.foreground(b);
    final mutedFg = DesignTokens.mutedForeground(b);
    final surface2 = DesignTokens.surface2of(b);
    final bg = DesignTokens.background(b);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(32),
        boxShadow: DesignTokens.shadowCard(b),
      ),
      child: Column(
        children: [
          Container(
            width: 224,
            height: 224,
            alignment: Alignment.center,
            decoration: const BoxDecoration(shape: BoxShape.circle),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 176,
                  height: 176,
                  decoration: BoxDecoration(
                    gradient: DesignTokens.aiGradient,
                    shape: BoxShape.circle,
                    boxShadow: DesignTokens.shadowCard(b),
                  ),
                ),
                Container(
                  width: 144,
                  height: 144,
                  decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(8, (i) {
                      final heights = [0.4, 0.8, 0.55, 1.0, 0.7, 0.9, 0.45, 0.75];
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: 6,
                        height: 40 * heights[i],
                        decoration: BoxDecoration(
                          gradient: DesignTokens.aiGradient,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Escuchando…', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: fg)),
          const SizedBox(height: 4),
          Text('Conversación full-duplex en tiempo real', style: TextStyle(fontSize: 12, color: mutedFg)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _CircleBtn(icon: LucideIcons.volume2, size: 44, bg: surface2, fg: fg.withOpacity(0.7)),
              const SizedBox(width: 12),
              _CircleBtn(icon: LucideIcons.pause, size: 56, bg: fg, fg: bg, onTap: onTalk),
              const SizedBox(width: 12),
              _CircleBtn(icon: LucideIcons.mic, size: 44, bg: surface2, fg: fg.withOpacity(0.7)),
            ],
          ),
        ],
      ),
    );
  }
}

class _XiaomiWorkouts extends StatefulWidget {
  @override
  State<_XiaomiWorkouts> createState() => _XiaomiWorkoutsState();
}

class _XiaomiWorkoutsState extends State<_XiaomiWorkouts> {
  bool _isLoading = false;
  List<HealthDataPoint> _workouts = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    final workouts = await HealthService.fetchWorkouts();
    if (mounted) {
      setState(() {
        _workouts = workouts;
        _isLoading = false;
      });
    }
  }

  Future<void> _runDiagnostic() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const AlertDialog(
        title: Text('Buscando en tu móvil...'),
        content: SizedBox(height: 60, child: Center(child: CircularProgressIndicator())),
      ),
    );
    try {
      final now = DateTime.now();
      final start = now.subtract(const Duration(days: 14));
      final health = Health();
      final types = [
        HealthDataType.WORKOUT,
        HealthDataType.STEPS,
        HealthDataType.HEART_RATE,
        HealthDataType.ACTIVE_ENERGY_BURNED,
        HealthDataType.DISTANCE_DELTA,
      ];
      String result = '';
      for (var type in types) {
        try {
          final data = await health.getHealthDataFromTypes(startTime: start, endTime: now, types: [type]);
          result += '${type.name}: ${data.length} reg.\n';
        } catch (e) {
          result += '${type.name}: ERROR\n';
        }
      }
      if (!mounted) return;
      Navigator.pop(context); // cerrar cargando
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Datos en Health Connect'),
          content: Text(result, style: const TextStyle(height: 1.5)),
          actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('CERRAR'))],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final card = DesignTokens.card(b);
    final fg = DesignTokens.foreground(b);
    final mutedFg = DesignTokens.mutedForeground(b);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(28),
        boxShadow: DesignTokens.shadowCard(b),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('REGISTROS · MI BAND',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.4, color: mutedFg)),
              InkWell(
                onTap: _fetchData,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(999)),
                  child: Row(
                    children: [
                      if (_isLoading)
                        const SizedBox(width: 8, height: 8, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 1.5))
                      else
                        Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFFFF6900), shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      Text(_isLoading ? 'SINCRONIZANDO' : 'XIAOMI', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Entrenamientos Xiaomi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: fg)),
          const SizedBox(height: 24),
          if (_workouts.isEmpty && !_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Column(
                  children: [
                    Text('No se encontraron entrenamientos.', style: TextStyle(color: mutedFg)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () async {
                            await HealthService.requestPermissions();
                            _fetchData();
                          },
                          icon: const Icon(Icons.key, size: 18),
                          label: const Text('Pedir Permisos'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00C897),
                            foregroundColor: Colors.white,
                            elevation: 0,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _runDiagnostic,
                          icon: const Icon(Icons.troubleshoot, size: 18),
                          label: const Text('Debug'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E1E1E),
                            foregroundColor: Colors.white,
                            elevation: 0,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          else
            ..._workouts.take(4).map((w) {
              // Extraer duración
              final duration = w.dateTo.difference(w.dateFrom);
              final min = duration.inMinutes;
              
              int kcal = 0;
              double dist = 0.0;
              String typeName = 'Entrenamiento';
              
              if (w.value is WorkoutHealthValue) {
                final workout = w.value as WorkoutHealthValue;
                kcal = (workout.totalEnergyBurned ?? 0).toInt();
                dist = (workout.totalDistance ?? 0) / 1000;
                typeName = workout.workoutActivityType.name.replaceAll('HealthWorkoutActivityType.', '');
              }
              
              String desc = '${w.dateFrom.day}/${w.dateFrom.month} · ${w.dateFrom.hour}:${w.dateFrom.minute.toString().padLeft(2, '0')} · $min min';
              if (dist > 0) desc += ' · ${dist.toStringAsFixed(1)} km';

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _WorkoutRow(
                  icon: LucideIcons.activity,
                  title: typeName,
                  desc: desc,
                  bpm: '--',
                  kcal: kcal > 0 ? '$kcal' : '--',
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _WorkoutRow extends StatelessWidget {
  const _WorkoutRow({
    required this.icon,
    required this.title,
    required this.desc,
    required this.bpm,
    required this.kcal,
  });
  final IconData icon;
  final String title;
  final String desc;
  final String bpm;
  final String kcal;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final fg = DesignTokens.foreground(b);
    final mutedFg = DesignTokens.mutedForeground(b);

    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFE0F2FE),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: const Color(0xFF475569)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: fg)),
              const SizedBox(height: 4),
              Text(desc, style: TextStyle(fontSize: 12, color: mutedFg)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: fg),
                children: [TextSpan(text: bpm), TextSpan(text: 'bpm', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: mutedFg))],
              ),
            ),
            const SizedBox(height: 4),
            Text('$kcal kcal', style: TextStyle(fontSize: 12, color: mutedFg)),
          ],
        ),
      ],
    );
  }
}

class _CircleBtn extends StatelessWidget {
  const _CircleBtn({required this.icon, required this.size, required this.bg, required this.fg, this.onTap});
  final IconData icon;
  final double size;
  final Color bg;
  final Color fg;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          boxShadow: DesignTokens.shadowCard(Theme.of(context).brightness),
        ),
        child: Icon(icon, size: size * 0.36, color: fg),
      ),
    );
  }
}

class _FocusModeCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final card = DesignTokens.card(b);
    final fg = DesignTokens.foreground(b);
    final mutedFg = DesignTokens.mutedForeground(b);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(DesignTokens.cardRadius),
        boxShadow: DesignTokens.shadowCard(b),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('MODO FOCUS · EJERCICIO 3 / 8',
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
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: fg),
              children: [const TextSpan(text: 'Press Inclinado'), TextSpan(text: ' · Mancuernas', style: TextStyle(color: mutedFg))],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _MetaBig(value: '4', unit: 'series', fg: fg, mutedFg: mutedFg),
              const SizedBox(width: 20),
              _MetaBig(value: '8–10', unit: 'reps', fg: fg, mutedFg: mutedFg),
              const SizedBox(width: 20),
              _MetaBig(value: '22kg', unit: '', fg: fg, mutedFg: mutedFg),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: DesignTokens.aiGradient,
              borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
              boxShadow: DesignTokens.shadowCard(b),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.camera, size: 18, color: Colors.white),
                SizedBox(width: 8),
                Text('Activar Cámara Edge AI',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
              ],
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
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: fg)),
        if (unit.isNotEmpty) Text(unit, style: TextStyle(fontSize: 11, color: mutedFg)),
      ],
    );
  }
}

/* ============================== NUTRICIÓN ============================== */

class _NutritionScreen extends StatelessWidget {
  const _NutritionScreen({required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MacrosOverview(),
          const SizedBox(height: 16),
          _CameraViewer(onTap: onOpen),
          const SizedBox(height: 16),
          _ScanResultCard(),
        ],
      ),
    );
  }
}

class _MacrosOverview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final card = DesignTokens.card(b);
    final fg = DesignTokens.foreground(b);
    final mutedFg = DesignTokens.mutedForeground(b);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(28),
        boxShadow: DesignTokens.shadowCard(b),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('HOY · JUEVES 25 JUN',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.4, color: mutedFg)),
                  const SizedBox(height: 8),
                  Text('Tus macros', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: fg)),
                ],
              ),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF1F5F9), // Un color suave para el rosco
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 6),
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('580', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: fg, height: 1.0)),
                    Text('RESTAN', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: mutedFg, letterSpacing: 0.5)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _MacroRow(label: 'Proteína', val: 92, total: 160, color: const Color(0xFF9D7BFF), fg: fg, mutedFg: mutedFg, muted: DesignTokens.muted(b)),
          const SizedBox(height: 16),
          _MacroRow(label: 'Carbohidratos', val: 178, total: 260, color: const Color(0xFF06B6D4), fg: fg, mutedFg: mutedFg, muted: DesignTokens.muted(b)),
          const SizedBox(height: 16),
          _MacroRow(label: 'Grasas', val: 48, total: 75, color: const Color(0xFFF87171), fg: fg, mutedFg: mutedFg, muted: DesignTokens.muted(b)),
        ],
      ),
    );
  }
}

class _MacroRow extends StatelessWidget {
  const _MacroRow({
    required this.label,
    required this.val,
    required this.total,
    required this.color,
    required this.fg,
    required this.mutedFg,
    required this.muted,
  });
  final String label;
  final int val;
  final int total;
  final Color color;
  final Color fg;
  final Color mutedFg;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    int faltan = (total - val).clamp(0, 9999);
    double pct = total > 0 ? (val / total).clamp(0.0, 1.0) : 0.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: fg)),
            RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg),
                children: [
                  TextSpan(text: '$val', style: const TextStyle(fontSize: 13)),
                  TextSpan(text: ' / ${total}g', style: TextStyle(color: mutedFg, fontWeight: FontWeight.w500)),
                  TextSpan(text: ' · faltan ${faltan}g', style: TextStyle(color: mutedFg, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 6,
          decoration: BoxDecoration(color: muted, borderRadius: BorderRadius.circular(999)),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: pct,
            child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999))),
          ),
        ),
      ],
    );
  }
}

class _CameraViewer extends StatelessWidget {
  const _CameraViewer({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final fg = DesignTokens.foreground(b);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DesignTokens.cardRadius),
        boxShadow: DesignTokens.shadowCard(b),
      ),
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.2),
                  colors: [DesignTokens.muted(b), DesignTokens.surface2of(b)],
                ),
              ),
            ),
            // corner guides
            Positioned(left: 20, top: 20, child: _corner(true, true)),
            Positioned(right: 20, top: 20, child: _corner(false, true)),
            Positioned(left: 20, bottom: 20, child: _corner(true, false)),
            Positioned(right: 20, bottom: 20, child: _corner(false, false)),
            // center content
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.10),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.camera, size: 20, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Text('Fotografía tu comida', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text('Visión MLLM · sin inputs manuales', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6))),
                ],
              ),
            ),
            // shutter
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: onTap,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.4), width: 4),
                    ),
                    alignment: Alignment.center,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(gradient: DesignTokens.aiGradient, shape: BoxShape.circle),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _corner(bool left, bool top) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        border: Border(
          left: left ? const BorderSide(color: Color(0xCCFFFFFF), width: 2) : BorderSide.none,
          top: top ? const BorderSide(color: Color(0xCCFFFFFF), width: 2) : BorderSide.none,
          right: !left ? const BorderSide(color: Color(0xCCFFFFFF), width: 2) : BorderSide.none,
          bottom: !top ? const BorderSide(color: Color(0xCCFFFFFF), width: 2) : BorderSide.none,
        ),
        borderRadius: BorderRadius.only(
          topLeft: (left && top) ? const Radius.circular(12) : Radius.zero,
          topRight: (!left && top) ? const Radius.circular(12) : Radius.zero,
          bottomLeft: (left && !top) ? const Radius.circular(12) : Radius.zero,
          bottomRight: (!left && !top) ? const Radius.circular(12) : Radius.zero,
        ),
      ),
    );
  }
}

class _ScanResultCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final card = DesignTokens.card(b);
    final fg = DesignTokens.foreground(b);
    final mutedFg = DesignTokens.mutedForeground(b);
    final surface1 = DesignTokens.surface1(b);
    final muted = DesignTokens.muted(b);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(DesignTokens.cardRadius),
        boxShadow: DesignTokens.shadowCard(b),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: DesignTokens.aiGradientSoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(LucideIcons.image, size: 20, color: fg.withOpacity(0.7)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ESCANEO · HACE 2 H',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.4, color: mutedFg)),
                    const SizedBox(height: 2),
                    Text('Salmón, quinoa y aguacate',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: fg)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text('NOVA 1 · No procesado',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF047857))),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _MacroChip(label: 'Proteína', value: '38g', pct: 0.7, fg: fg, mutedFg: mutedFg, surface1: surface1, muted: muted)),
              const SizedBox(width: 8),
              Expanded(child: _MacroChip(label: 'Carbos', value: '42g', pct: 0.5, fg: fg, mutedFg: mutedFg, surface1: surface1, muted: muted)),
              const SizedBox(width: 8),
              Expanded(child: _MacroChip(label: 'Grasas', value: '18g', pct: 0.4, fg: fg, mutedFg: mutedFg, surface1: surface1, muted: muted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroChip extends StatelessWidget {
  const _MacroChip({required this.label, required this.value, required this.pct, required this.fg, required this.mutedFg, required this.surface1, required this.muted});
  final String label;
  final String value;
  final double pct;
  final Color fg;
  final Color mutedFg;
  final Color surface1;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: surface1, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.0, color: mutedFg)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: fg)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: muted,
              valueColor: const AlwaysStoppedAnimation<Color>(DesignTokens.aiVia),
            ),
          ),
        ],
      ),
    );
  }
}

/* ============================== CLÍNICA ============================== */

class _ClinicScreen extends StatelessWidget {
  const _ClinicScreen({required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ClinicalImporter(onTap: onOpen),
          const SizedBox(height: 16),
          _CompositionChart(),
          const SizedBox(height: 16),
          _PostureMesh(),
        ],
      ),
    );
  }
}

class _ClinicalImporter extends StatelessWidget {
  const _ClinicalImporter({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final card = DesignTokens.card(b);
    final border = DesignTokens.border(b);
    final fg = DesignTokens.foreground(b);
    final mutedFg = DesignTokens.mutedForeground(b);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DesignTokens.cardRadius),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(DesignTokens.cardRadius),
          border: Border.all(color: border, width: 2),
          boxShadow: DesignTokens.shadowSoft(b),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: DesignTokens.aiGradientSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(LucideIcons.upload, size: 20, color: fg),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Importar archivo clínico',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: fg)),
                  const SizedBox(height: 2),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(fontSize: 12, color: mutedFg),
                      children: [
                        const TextSpan(text: 'PDF médico, analítica o '),
                        TextSpan(text: 'DICOM (DEXA)', style: TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompositionChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final card = DesignTokens.card(b);
    final fg = DesignTokens.foreground(b);
    final mutedFg = DesignTokens.mutedForeground(b);
    final lean = [40, 42, 43, 45, 46, 48, 49];
    final fat = [28, 27, 26, 25, 24, 22, 21];
    const min = 15, max = 55;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(DesignTokens.cardRadius),
        boxShadow: DesignTokens.shadowCard(b),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('COMPOSICIÓN · 6 MESES',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.4, color: mutedFg)),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: fg),
              children: [const TextSpan(text: 'Grasa visceral '), TextSpan(text: 'vs.', style: TextStyle(color: mutedFg)), const TextSpan(text: ' masa magra')],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 110,
            child: CustomPaint(
              size: Size.infinite,
              painter: _CompPainter(lean: lean, fat: fat, min: min, max: max),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(gradient: DesignTokens.aiGradient, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text('Masa magra', style: TextStyle(fontSize: 12, color: fg)),
              const SizedBox(width: 4),
              const Icon(LucideIcons.trendingUp, size: 14, color: Color(0xFF059669)),
              const Spacer(),
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFFB923C), shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text('Grasa visceral', style: TextStyle(fontSize: 12, color: mutedFg)),
              const SizedBox(width: 4),
              const Icon(LucideIcons.trendingDown, size: 14, color: Color(0xFF059669)),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompPainter extends CustomPainter {
  const _CompPainter({required this.lean, required this.fat, required this.min, required this.max});
  final List<int> lean;
  final List<int> fat;
  final int min;
  final int max;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    Path path(List<int> arr) {
      final p = Path();
      for (int i = 0; i < arr.length; i++) {
        final x = (i / (arr.length - 1)) * w;
        final y = h - ((arr[i] - min) / (max - min)) * h;
        if (i == 0) p.moveTo(x, y);
        else p.lineTo(x, y);
      }
      return p;
    }
    // lean fill
    final leanPath = path(lean);
    final fillPath = Path.from(leanPath)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    final rect = Offset.zero & size;
    final grad = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [DesignTokens.aiVia.withOpacity(0.35), DesignTokens.aiVia.withOpacity(0)],
    ).createShader(rect);
    canvas.drawPath(fillPath, Paint()..shader = grad..style = PaintingStyle.fill);
    canvas.drawPath(leanPath, Paint()
      ..color = DesignTokens.aiVia
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round);
    // fat dashed
    final fatPath = path(fat);
    _drawDashed(canvas, fatPath, const Color(0xFFFB923C), 2.5);
  }

  void _drawDashed(Canvas canvas, Path p, Color color, double width) {
    final metrics = p.computeMetrics();
    final dashLen = 4.0, gapLen = 4.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    for (final m in metrics) {
      double dist = 0;
      while (dist < m.length) {
        final next = (dist + dashLen).clamp(0.0, m.length);
        canvas.drawPath(m.extractPath(dist, next), paint);
        dist = next + gapLen;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CompPainter old) => old.lean != lean || old.fat != fat;
}

class _PostureMesh extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final card = DesignTokens.card(b);
    final fg = DesignTokens.foreground(b);
    final mutedFg = DesignTokens.mutedForeground(b);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(DesignTokens.cardRadius),
        boxShadow: DesignTokens.shadowCard(b),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('POSTURA 3D · HISTÓRICO',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.4, color: mutedFg)),
                    const SizedBox(height: 4),
                    Text('Asimetría corregida',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: fg)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text('−38%',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF047857))),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _MeshFigure(label: 'Ene', tilt: -8, muted: true)),
              const SizedBox(width: 12),
              Expanded(child: _MeshFigure(label: 'Hoy', tilt: -1, muted: false)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MeshFigure extends StatelessWidget {
  const _MeshFigure({required this.label, required this.tilt, required this.muted});
  final String label;
  final double tilt;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final fg = DesignTokens.foreground(b);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.3),
                  colors: [DesignTokens.surface1(b), DesignTokens.muted(b)],
                ),
              ),
            ),
            Center(
              child: Transform.rotate(
                angle: tilt * 3.1416 / 180,
                child: Icon(LucideIcons.user,
                    size: 96, color: muted ? fg.withOpacity(0.3) : fg.withOpacity(0.7)),
              ),
            ),
            CustomPaint(
              size: Size.infinite,
              painter: _GridPainter(),
            ),
            Positioned(
              bottom: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF1B1B20))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.15)
      ..strokeWidth = 0.4;
    final rows = 8;
    final cols = 7;
    for (int i = 1; i < rows; i++) {
      final y = (i / rows) * size.height;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    for (int i = 1; i < cols; i++) {
      final x = (i / cols) * size.width;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/* ============================== BOTTOM NAV ============================== */

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.active, required this.onChange});

  final String active;
  final ValueChanged<String> onChange;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('dashboard', 'Dashboard', LucideIcons.home),
      ('coach', 'Entrenador', LucideIcons.dumbbell),
      ('nutrition', 'Nutrición', LucideIcons.apple),
      ('clinic', 'Clínica', LucideIcons.activity),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: GlassCard(
        radius: DesignTokens.cardRadius,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: items.map((it) {
            final isActive = it.$1 == active;
            final fg = DesignTokens.foreground(Theme.of(context).brightness);
            final mutedFg = DesignTokens.mutedForeground(Theme.of(context).brightness);
            return Expanded(
              child: InkWell(
                onTap: () => onChange(it.$1),
                borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(it.$3, size: 22, color: isActive ? fg : mutedFg),
                      const SizedBox(height: 4),
                      AiGradientText(it.$2,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: isActive ? fg : mutedFg)),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}