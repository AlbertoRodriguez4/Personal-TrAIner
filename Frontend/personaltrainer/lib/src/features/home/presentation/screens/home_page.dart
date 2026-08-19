import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:health/health.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../services/health_service.dart';
import '../../../../core/providers/theme_provider.dart';

import '../../../../core/providers/routine_provider.dart';
import '../../../../core/providers/daily_summary_provider.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/ui/ai_animations.dart';
import '../../../../core/ui/analysis_report.dart';
import '../../../../core/ui/ai_gradient_text.dart';
import '../../../../core/ui/glass_card.dart';
import '../../../../services/api_service.dart';
import '../../../ai_coach/presentation/screens/ai_coach_page.dart';
import '../../../nutrition/presentation/widgets/hydration_card.dart';
import '../../../nutrition/presentation/widgets/manual_food_entry_card.dart';
import '../../../nutrition/presentation/widgets/supplements_card.dart';
import '../../../nutrition/presentation/widgets/todays_meals_card.dart';
import '../../../routine/models/exercise.dart';
import '../../../routine/presentation/screens/quick_add_page.dart';
import '../../../routine/presentation/screens/routine_builder_page.dart';
import '../../../routine/presentation/screens/routine_view_page.dart';
import '../../../routine/presentation/screens/workout_session_page.dart';
import '../../../profile/presentation/screens/profile_setup_page.dart';
import '../../../../core/route_loaders.dart';
import 'backend_features_page.dart';
import '../../../health/presentation/screens/workout_detail_page.dart';
import '../../../health/presentation/widgets/health_records_history.dart';

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
              _Header(onLogout: _logout),
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
      case 'progress':
        return const ProgressRoute(isTab: true);
      case 'health':
        return const _HealthScreen();
      default:
        return _DashboardScreen(onOpenAiCoach: _openAiCoach);
    }
  }

  Future<void> _logout(BuildContext context) async {
    await ApiService.logout();
    widget.onSessionClosed?.call();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
  }

  void _openAiCoach(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const AiCoachPage()));

  void _openBackend(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const BackendFeaturesPage()));
}

/* ============================== HEADER ============================== */

class _Header extends StatelessWidget {
  const _Header({this.onLogout});
  final Future<void> Function(BuildContext)? onLogout;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dias = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];
    final meses = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    final fecha =
        '${dias[now.weekday - 1]} · ${now.day} ${meses[now.month - 1]}';
    final mutedFg = DesignTokens.mutedForeground(Theme.of(context).brightness);
    final fg = DesignTokens.foreground(Theme.of(context).brightness);

    return GlassCard(
      radius: 0,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      shadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                          TextSpan(
                            text: 'AI',
                            style: TextStyle(fontStyle: FontStyle.italic),
                          ),
                          TextSpan(text: 'ner'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () =>
                    context.read<ThemeProvider>().toggleTheme(context),
                icon: Icon(
                  Theme.of(context).brightness == Brightness.dark
                      ? LucideIcons.sun
                      : LucideIcons.moon,
                ),
                color: fg,
              ),
              // La foto de perfil abre el configurador directamente, sin menú
              // intermedio: era un desplegable con una sola opción. Cerrar
              // sesión se ha mudado dentro del configurador, que es la pantalla
              // de "tu cuenta".
              if (onLogout != null)
                IconButton(
                  tooltip: 'Tu perfil',
                  icon: Icon(LucideIcons.userCircle2, color: fg),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProfileSetupPage(
                        onLogout: onLogout,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/devices'),
                  child: const _LiveSync(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/devices'),
                  child: const _StepsPill(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LiveSync extends StatefulWidget {
  const _LiveSync();

  @override
  State<_LiveSync> createState() => _LiveSyncState();
}

class _LiveSyncState extends State<_LiveSync> {
  int? _hr;
  bool _loading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    // El punto verde pulsa como si fuera en vivo, así que tiene que serlo:
    // una sola lectura al montar se queda pegada en "--" toda la sesión si
    // Health Connect todavía no tenía nada sincronizado en ese momento (p.
    // ej. justo tras abrir la app), aunque el dato aparezca segundos después
    // — que es exactamente lo que hace verlo sí en Dispositivos, que lee lo
    // mismo pero más tarde.
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _load());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final hr = await HealthService.fetchLatestHeartRate();
    if (mounted) {
      setState(() {
        _hr = hr;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final fg = DesignTokens.foreground(b);
    final mutedFg = DesignTokens.mutedForeground(b);
    final surface1 = DesignTokens.surface1(b);
    final border = DesignTokens.border(b);
    return Container(
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
                TextSpan(text: _loading ? '--' : (_hr == null ? '--' : '$_hr')),
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
    );
  }
}

class _StepsPill extends StatefulWidget {
  const _StepsPill();

  @override
  State<_StepsPill> createState() => _StepsPillState();
}

class _StepsPillState extends State<_StepsPill> {
  int _steps = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final steps = await HealthService.fetchTodaySteps();
    if (mounted) {
      setState(() {
        _steps = steps;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final fg = DesignTokens.foreground(b);
    final mutedFg = DesignTokens.mutedForeground(b);
    final surface1 = DesignTokens.surface1(b);
    final border = DesignTokens.border(b);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: surface1,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.footprints, size: 14, color: fg.withOpacity(0.7)),
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
                TextSpan(
                  text: _loading
                      ? '--'
                      : (_steps >= 1000
                            ? '${(_steps / 1000).toStringAsFixed(1)}k'
                            : '$_steps'),
                ),
                TextSpan(
                  text: 'pasos',
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
    );
  }
}

/* ============================== DASHBOARD ============================== */

/// Dashboard de Inicio: solo 3 secciones a propósito — acceso al chat de
/// Pulso, la alerta predictiva, y los últimos entrenamientos. El resto de lo
/// que vivía aquí (accesos rápidos, anillos de carga/macros, hidratación y
/// suplementos, atajo de rutinas) ya tiene un hogar en sus propias pestañas
/// (Nutrición, Progreso, Entrenar); duplicarlo en Inicio era ruido.
class _DashboardScreen extends StatelessWidget {
  const _DashboardScreen({required this.onOpenAiCoach});

  final void Function(BuildContext) onOpenAiCoach;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AICoachCTA(onTalk: () => onOpenAiCoach(context)),
          const SizedBox(height: 16),
          _PredictiveAlert(),
          const SizedBox(height: 16),
          _NavTile(
            tile: (
              icon: LucideIcons.activity,
              title: 'Dispositivos',
              sub: 'Sync Center',
              onTap: () => Navigator.pushNamed(context, '/devices'),
            ),
          ),
          const SizedBox(height: 16),
          const _RecentWorkoutsSection(),
        ],
      ),
    );
  }
}

/// Los 2-3 entrenamientos más recientes de Health Connect, en formato
/// compacto (a diferencia del antiguo `_WorkoutCard`, que mostraba solo el
/// último a tamaño completo).
class _RecentWorkoutsSection extends StatefulWidget {
  const _RecentWorkoutsSection();

  @override
  State<_RecentWorkoutsSection> createState() => _RecentWorkoutsSectionState();
}

class _RecentWorkoutsSectionState extends State<_RecentWorkoutsSection> {
  bool _isLoading = true;
  List<HealthDataPoint> _workouts = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await HealthService.fetchWorkouts();
    final valid = all.where((w) {
      if (w.value is WorkoutHealthValue) {
        return (w.value as WorkoutHealthValue).workoutActivityType !=
            HealthWorkoutActivityType.WALKING;
      }
      return true;
    }).toList()..sort((a, b) => b.dateFrom.compareTo(a.dateFrom));

    if (!mounted) return;
    setState(() {
      _workouts = valid.take(3).toList();
      _isLoading = false;
    });

    // Fire-and-forget: guarda en el backend los entrenamientos de Health
    // Connect que todavía no tenía, con FC real. No bloquea esta pantalla —
    // es idempotente (dedupe por fecha de inicio) y se reintenta solo la
    // próxima vez que se abra Inicio si esta vez falla por red.
    unawaited(HealthService.syncWorkoutsToBackend());
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final card = DesignTokens.card(b);
    final mutedFg = DesignTokens.mutedForeground(b);

    if (_isLoading) {
      return Container(
        height: 140,
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(28),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

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
          Text(
            'ÚLTIMOS ENTRENAMIENTOS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.4,
              color: mutedFg,
            ),
          ),
          const SizedBox(height: 14),
          if (_workouts.isEmpty)
            Text(
              'Aún no hay entrenamientos registrados.',
              style: TextStyle(fontSize: 13, color: mutedFg),
            )
          else
            for (var i = 0; i < _workouts.length; i++) ...[
              if (i > 0) Divider(height: 20, color: DesignTokens.border(b)),
              _RecentWorkoutRow(workout: _workouts[i]),
            ],
        ],
      ),
    );
  }
}

class _RecentWorkoutRow extends StatelessWidget {
  const _RecentWorkoutRow({required this.workout});
  final HealthDataPoint workout;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final fg = DesignTokens.foreground(b);
    final mutedFg = DesignTokens.mutedForeground(b);

    int kcal = 0;
    String typeName = 'Entrenamiento';
    if (workout.value is WorkoutHealthValue) {
      final w = workout.value as WorkoutHealthValue;
      kcal = (w.totalEnergyBurned ?? 0).toInt();
      typeName = HealthService.translateWorkoutActivityType(
        w.workoutActivityType,
      );
    }
    final min = workout.dateTo.difference(workout.dateFrom).inMinutes;

    final now = DateTime.now();
    final isToday =
        workout.dateFrom.year == now.year &&
        workout.dateFrom.month == now.month &&
        workout.dateFrom.day == now.day;
    final isYesterday =
        workout.dateFrom.year == now.year &&
        workout.dateFrom.month == now.month &&
        workout.dateFrom.day == now.day - 1;
    final dateStr = isToday
        ? 'Hoy'
        : (isYesterday
              ? 'Ayer'
              : '${workout.dateFrom.day}/${workout.dateFrom.month}');

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => WorkoutDetailPage(workout: workout)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: DesignTokens.aiGradientSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(LucideIcons.heart, size: 16, color: fg),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    typeName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
                  ),
                  Text(
                    '$dateStr · $min min',
                    style: TextStyle(fontSize: 12, color: mutedFg),
                  ),
                ],
              ),
            ),
            if (kcal > 0)
              Text(
                '$kcal kcal',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: mutedFg,
                ),
              ),
            const SizedBox(width: 6),
            Icon(LucideIcons.chevronRight, size: 16, color: mutedFg),
          ],
        ),
      ),
    );
  }
}

class _PredictiveAlert extends StatefulWidget {
  @override
  State<_PredictiveAlert> createState() => _PredictiveAlertState();
}

class _PredictiveAlertState extends State<_PredictiveAlert> {
  ReadinessSummary? _readiness;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    HealthService.fetchSleepAndReadiness().then((r) {
      if (mounted) {
        setState(() {
          _readiness = r;
          _loading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        height: 72,
        decoration: BoxDecoration(
          gradient: DesignTokens.warnSoft,
          borderRadius: BorderRadius.circular(DesignTokens.cardRadius),
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final title = _readiness?.alertTitle ?? 'ESTADO � SIN DATOS HC';
    final body =
        _readiness?.alertBody ??
        'Activa Health Connect para ver tu alerta de readiness.';
    final level = _readiness?.level ?? ReadinessLevel.ok;

    final iconColor = level == ReadinessLevel.fatigue
        ? const Color(0xFFC2410C)
        : level == ReadinessLevel.warning
        ? const Color(0xFFD97706)
        : const Color(0xFF059669);
    final titleColor = level == ReadinessLevel.fatigue
        ? const Color(0xFF9A3412)
        : level == ReadinessLevel.warning
        ? const Color(0xFF92400E)
        : const Color(0xFF065F46);
    final iconData = level == ReadinessLevel.ok
        ? LucideIcons.checkCircle
        : LucideIcons.alertTriangle;

    final b = Theme.of(context).brightness;
    final fg = DesignTokens.foreground(b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: level == ReadinessLevel.ok
            ? DesignTokens.aiGradientSoft
            : DesignTokens.warnSoft,
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
            child: Icon(iconData, size: 16, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.4,
                    color: titleColor.withOpacity(0.85),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: fg,
                    height: 1.35,
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

class _Row extends StatelessWidget {
  const _Row({required this.a, required this.b});
  final Widget a;
  final Widget b;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: a),
      const SizedBox(width: 12),
      Expanded(child: b),
    ],
  );
}

class _WorkoutCard extends StatefulWidget {
  const _WorkoutCard({
    required this.routinesCount,
    required this.onTap,
    this.onLongPress,
  });
  final int routinesCount;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  State<_WorkoutCard> createState() => _WorkoutCardState();
}

class _WorkoutCardState extends State<_WorkoutCard> {
  bool _isLoading = true;
  HealthDataPoint? _latestWorkout;
  String _bpm = '--';

  @override
  void initState() {
    super.initState();
    _fetchLatestWorkout();
  }

  Future<void> _fetchLatestWorkout() async {
    final allWorkouts = await HealthService.fetchWorkouts();
    final validWorkouts = allWorkouts.where((w) {
      if (w.value is WorkoutHealthValue) {
        return (w.value as WorkoutHealthValue).workoutActivityType !=
            HealthWorkoutActivityType.WALKING;
      }
      return true;
    }).toList();

    validWorkouts.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));

    if (validWorkouts.isNotEmpty) {
      final latest = validWorkouts.first;
      if (mounted) {
        setState(() {
          _latestWorkout = latest;
          _isLoading = false;
        });
      }

      final details = await HealthService.fetchWorkoutDetails(
        latest.dateFrom,
        latest.dateTo,
      );
      final hrData = details['heart_rate'] ?? [];
      if (hrData.isNotEmpty) {
        final hrValues = hrData
            .map((e) => (e.value as NumericHealthValue).numericValue.toDouble())
            .toList();
        final avg = hrValues.reduce((a, b) => a + b) / hrValues.length;
        if (mounted) {
          setState(() {
            _bpm = avg.round().toString();
          });
        }
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final card = DesignTokens.card(b);
    final fg = DesignTokens.foreground(b);
    final mutedFg = DesignTokens.mutedForeground(b);
    final surface1 = DesignTokens.surface1(b);

    if (_isLoading) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(28),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_latestWorkout == null) {
      return const SizedBox.shrink();
    }

    final w = _latestWorkout!;
    final duration = w.dateTo.difference(w.dateFrom);
    final min = duration.inMinutes;

    int kcal = 0;
    double dist = 0.0;
    String typeName = 'Entrenamiento';

    if (w.value is WorkoutHealthValue) {
      final workout = w.value as WorkoutHealthValue;
      kcal = (workout.totalEnergyBurned ?? 0).toInt();
      dist = (workout.totalDistance ?? 0) / 1000;
      typeName = HealthService.translateWorkoutActivityType(
        workout.workoutActivityType,
      );
    }

    final now = DateTime.now();
    final isToday =
        w.dateFrom.year == now.year &&
        w.dateFrom.month == now.month &&
        w.dateFrom.day == now.day;
    final isYesterday =
        w.dateFrom.year == now.year &&
        w.dateFrom.month == now.month &&
        w.dateFrom.day == now.day - 1;
    String dateStr = isToday
        ? 'Hoy'
        : (isYesterday ? 'Ayer' : '${w.dateFrom.day}/${w.dateFrom.month}');
    String timeStr =
        '${w.dateFrom.hour.toString().padLeft(2, '0')}:${w.dateFrom.minute.toString().padLeft(2, '0')}';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => WorkoutDetailPage(workout: w)),
        );
      },
      onLongPress: widget.onLongPress,
      child: Container(
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
                Text(
                  'ÚLTIMA ACTIVIDAD',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.4,
                    color: mutedFg,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF6900),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'XIAOMI',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              typeName,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: fg,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$dateStr · $timeStr',
              style: TextStyle(
                fontSize: 13,
                color: mutedFg,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _StatPill(
                    val: '$min min',
                    sub: 'DURACIÓN',
                    surface1: surface1,
                    fg: fg,
                    mutedFg: mutedFg,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatPill(
                    val: _bpm,
                    sub: 'BPM MED',
                    surface1: surface1,
                    fg: fg,
                    mutedFg: mutedFg,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatPill(
                    val: kcal > 0 ? '$kcal' : '--',
                    sub: 'KCAL',
                    surface1: surface1,
                    fg: fg,
                    mutedFg: mutedFg,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatPill(
                    val: dist > 0 ? '${dist.toStringAsFixed(1)} km' : '--',
                    sub: 'DIST.',
                    surface1: surface1,
                    fg: fg,
                    mutedFg: mutedFg,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.val,
    required this.sub,
    required this.surface1,
    required this.fg,
    required this.mutedFg,
  });
  final String val;
  final String sub;
  final Color surface1;
  final Color fg;
  final Color mutedFg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: surface1,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            val,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: mutedFg,
            ),
          ),
        ],
      ),
    );
  }
}

/* ───────────────── AICoachCTA (réplica de index.tsx AICoachCTA) ───────────────── */

class _AICoachCTA extends StatelessWidget {
  const _AICoachCTA({required this.onTalk});
  final VoidCallback onTalk;

  static const _modules = [
    (icon: LucideIcons.dumbbell, label: 'Crear rutina'),
    (icon: LucideIcons.moon, label: 'Sueño'),
    (icon: LucideIcons.apple, label: 'Nutrición'),
    (icon: LucideIcons.lineChart, label: 'Progreso'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: DesignTokens.aiGradient,
        borderRadius: BorderRadius.circular(32),
        boxShadow: DesignTokens.shadowCard(Theme.of(context).brightness),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -56,
            child: _GlowBlob(size: 176, opacity: 0.20),
          ),
          Positioned(
            left: -40,
            bottom: -64,
            child: _GlowBlob(size: 160, opacity: 0.10),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          AiPulseEffect(
                            child: Container(
                              width: 56,
                              height: 56,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.20),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  const Icon(
                                    LucideIcons.sparkles,
                                    size: 28,
                                    color: Colors.white,
                                  ),
                                  Positioned(
                                    right: -2,
                                    top: -2,
                                    child: Container(
                                      width: 14,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF34D399),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.8),
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'PULSO · AI COACH',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.6,
                                    color: Colors.white.withOpacity(0.75),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Tu entrenador IA',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -0.3,
                                    height: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.20),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'EN LÍNEA',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Crea y edita rutinas, interpreta tu sueño y ajusta tus macros. Pulso lee tus datos reales y actúa por ti.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.88),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    for (final m in _modules) ...[
                      if (m != _modules.first) const SizedBox(width: 8),
                      Expanded(
                        child: _ModuleShortcut(
                          icon: m.icon,
                          label: m.label,
                          onTap: onTalk,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  child: InkWell(
                    onTap: onTalk,
                    borderRadius: BorderRadius.circular(999),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            LucideIcons.messageSquare,
                            size: 16,
                            color: DesignTokens.lightForeground.withOpacity(
                              0.35,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Escribe a Pulso…',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: DesignTokens.lightForeground.withOpacity(
                                  0.5,
                                ),
                              ),
                            ),
                          ),
                          Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              gradient: DesignTokens.aiGradient,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              LucideIcons.chevronRight,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
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

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.size, required this.opacity});
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(opacity),
        ),
      ),
    );
  }
}

class _ModuleShortcut extends StatelessWidget {
  const _ModuleShortcut({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.15),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: Colors.white),
              const SizedBox(height: 5),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ───────────────── HealthHubGrid (reemplazo de NewSectionsRow) ───────────────── */

/// 'Dispositivos' vivía aquí y se mudó a Inicio (entre la alerta de sueño/
/// readiness y los entrenamientos recientes): es donde tiene sentido revisar
/// la conexión con el reloj antes de entrenar, no en la pestaña de Salud.
class _HealthHubGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tiles = [
      (
        icon: LucideIcons.heart,
        title: 'Recuperación',
        sub: 'Sueño & VFC IA',
        onTap: () => Navigator.pushNamed(context, '/recovery'),
      ),
      (
        icon: LucideIcons.upload,
        title: 'Clínica',
        sub: 'Importar datos',
        onTap: () => Navigator.pushNamed(context, '/clinic/import'),
      ),
      (
        icon: LucideIcons.scanLine,
        title: 'Físico',
        sub: 'Análisis por fotos',
        onTap: () => Navigator.pushNamed(context, '/physique'),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _NavTile(tile: tiles[0])),
            const SizedBox(width: 12),
            Expanded(child: _NavTile(tile: tiles[1])),
          ],
        ),
        const SizedBox(height: 12),
        _NavTile(tile: tiles[2]),
      ],
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.tile});
  final ({IconData icon, String title, String sub, VoidCallback onTap}) tile;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final card = DesignTokens.card(b);
    final fg = DesignTokens.foreground(b);
    final mutedFg = DesignTokens.mutedForeground(b);
    return Material(
      color: card,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: tile.onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: DesignTokens.aiGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(tile.icon, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tile.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: fg,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tile.sub,
                      style: TextStyle(fontSize: 11, color: mutedFg),
                    ),
                  ],
                ),
              ),
              Icon(LucideIcons.chevronRight, size: 18, color: mutedFg),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pestaña "Entrenar": la rutina de hoy (real, de `RoutineProvider`) primero,
/// luego el resumen de la sesión de hoy si ya se entrenó, el insight de
/// `_RagBubble`, el historial de Mi Band y los atajos de rutina. `onOpen`
/// (abrir el chat de Pulso) ya no hace falta aquí — vivía en el botón central
/// del antiguo `_VoiceHero`, una UI de voz decorativa sin backend real detrás;
/// el acceso a Pulso ya está en la home y en el propio bottom nav.
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
          const _TodayRoutineHero(),
          const SizedBox(height: 16),
          const _TodaySummaryStats(),
          const SizedBox(height: 16),
          _RagBubble(),
          const SizedBox(height: 16),
          _XiaomiWorkouts(),
          const SizedBox(height: 16),
          _RoutineShortcuts(),
        ],
      ),
    );
  }
}

class _TodayRoutineHero extends StatelessWidget {
  const _TodayRoutineHero();

  static const _diasSemana = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final fg = DesignTokens.foreground(b);
    final mutedFg = DesignTokens.mutedForeground(b);
    final routines = context.watch<RoutineProvider>().routines;
    // La más reciente hace de "activa": mismo criterio que ya usa
    // `_openQuickAddForToday` más arriba en este archivo — el backend ordena
    // por `updated_at DESC` y pone `activa: true` solo en la última creada.
    final routine = routines.isNotEmpty ? routines.first : null;
    final hoy = _diasSemana[DateTime.now().weekday - 1];
    final dayIndex = routine?.days.indexWhere((d) => d.dayOfWeek == hoy) ?? -1;
    final day = dayIndex >= 0 ? routine!.days[dayIndex] : null;

    if (routine == null || day == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: DesignTokens.card(b),
          borderRadius: BorderRadius.circular(28),
          boxShadow: DesignTokens.shadowCard(b),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              routine == null
                  ? 'Sin rutina todavía'
                  : 'Hoy ($hoy) toca descanso',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: fg,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              routine == null
                  ? 'Crea tu primera rutina para ver aquí el día de hoy.'
                  : 'Tu rutina activa no tiene ejercicios asignados a $hoy.',
              style: TextStyle(fontSize: 13, color: mutedFg),
            ),
          ],
        ),
      );
    }

    final totalSeries = day.exercises.fold<int>(
      0,
      (sum, e) => sum + (e.sets ?? 0),
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DesignTokens.card(b),
        borderRadius: BorderRadius.circular(28),
        boxShadow: DesignTokens.shadowCard(b),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'HOY · ${hoy.toUpperCase()}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.4,
                    color: mutedFg,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  gradient: DesignTokens.aiGradientSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Rutina activa',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            day.focus?.isNotEmpty == true ? day.focus! : routine.name,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
          Text(
            routine.activityLabel,
            style: TextStyle(fontSize: 13, color: mutedFg),
          ),
          const SizedBox(height: 12),
          Text(
            '${day.exercises.length} ejercicios · $totalSeries series',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: mutedFg,
            ),
          ),
          const SizedBox(height: 20),
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => WorkoutSessionPage(routine: routine),
                ),
              ),
              borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
              child: Ink(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  gradient: DesignTokens.aiGradient,
                  borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
                  boxShadow: DesignTokens.shadowCard(b),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(LucideIcons.play, size: 18, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      'Iniciar ${day.focus?.isNotEmpty == true ? day.focus! : hoy}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// FC media / duración / calorías del entrenamiento de HOY (Health Connect).
/// No incluye "volumen" (tonelaje): ni `WorkoutSessionProvider` ni el modelo
/// de ejercicios guardan peso×reps completados, así que no hay de dónde
/// sacar ese dato real — mejor 3 stats reales que 4 con una inventada.
class _TodaySummaryStats extends StatefulWidget {
  const _TodaySummaryStats();

  @override
  State<_TodaySummaryStats> createState() => _TodaySummaryStatsState();
}

class _TodaySummaryStatsState extends State<_TodaySummaryStats> {
  bool _isLoading = true;
  HealthDataPoint? _todayWorkout;
  String _bpm = '--';
  int? _kcal;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    // El entrenamiento de hoy es el que más probablemente siga sincronizando
    // (FC granular, calorías) aunque la sesión ya aparezca en Health Connect
    // — igual que el pulso del header, una sola consulta al montar se queda
    // pegada en "--" el resto de la sesión si llega demasiado pronto.
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _load());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final all = await HealthService.fetchWorkouts();
    final now = DateTime.now();
    final today = all.where((w) {
      if (w.value is WorkoutHealthValue &&
          (w.value as WorkoutHealthValue).workoutActivityType ==
              HealthWorkoutActivityType.WALKING) {
        return false;
      }
      return w.dateFrom.year == now.year &&
          w.dateFrom.month == now.month &&
          w.dateFrom.day == now.day;
    }).toList()..sort((a, b) => b.dateFrom.compareTo(a.dateFrom));

    if (!mounted) return;
    if (today.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }
    final w = today.first;
    setState(() {
      _todayWorkout = w;
      _isLoading = false;
    });

    final details = await HealthService.fetchWorkoutDetails(
      w.dateFrom,
      w.dateTo,
    );
    final hrData = details['heart_rate'] ?? [];
    final calData = details['calories'] ?? [];
    if (!mounted) return;
    setState(() {
      if (hrData.isNotEmpty) {
        final values = hrData
            .map((e) => (e.value as NumericHealthValue).numericValue.toDouble())
            .toList();
        final avg = values.reduce((a, b) => a + b) / values.length;
        _bpm = avg.round().toString();
      }

      // `totalEnergyBurned` sale de TOTAL_CALORIES_BURNED en Health Connect;
      // Mi Fitness solo escribe la variante "activa" para estas sesiones —
      // mismo respaldo que ya usa workout_detail_page.dart, reaprovechando
      // `calData` (ya viene en la misma llamada, sin consulta extra).
      int? kcal;
      if (w.value is WorkoutHealthValue) {
        kcal = (w.value as WorkoutHealthValue).totalEnergyBurned;
      }
      if ((kcal == null || kcal <= 0) && calData.isNotEmpty) {
        final suma = calData
            .where((p) => p.value is NumericHealthValue)
            .fold<double>(
              0,
              (s, p) => s + (p.value as NumericHealthValue).numericValue.toDouble(),
            );
        if (suma > 0) kcal = suma.round();
      }
      _kcal = kcal;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _todayWorkout == null) return const SizedBox.shrink();

    final b = Theme.of(context).brightness;
    final fg = DesignTokens.foreground(b);
    final mutedFg = DesignTokens.mutedForeground(b);
    final surface1 = DesignTokens.surface1(b);
    final w = _todayWorkout!;
    final min = w.dateTo.difference(w.dateFrom).inMinutes;
    final kcal = _kcal ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DesignTokens.card(b),
        borderRadius: BorderRadius.circular(28),
        boxShadow: DesignTokens.shadowCard(b),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'RESUMEN DE HOY',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.4,
                  color: mutedFg,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: DesignTokens.success(b).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Completado',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: DesignTokens.success(b),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StatPill(
                  val: _bpm,
                  sub: 'FC MEDIA',
                  surface1: surface1,
                  fg: fg,
                  mutedFg: mutedFg,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatPill(
                  val: '$min min',
                  sub: 'DURACIÓN',
                  surface1: surface1,
                  fg: fg,
                  mutedFg: mutedFg,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatPill(
                  val: kcal > 0 ? '$kcal' : '--',
                  sub: 'CALORÍAS',
                  surface1: surface1,
                  fg: fg,
                  mutedFg: mutedFg,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Abre la alta rápida sobre el día de HOY de la primera rutina guardada y
/// persiste lo añadido. Si no hay rutina todavía, manda al constructor: no
/// tiene sentido añadir ejercicios a ningún sitio.
Future<void> _openQuickAddForToday(BuildContext context) async {
  const dias = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];
  final hoy = dias[DateTime.now().weekday - 1];

  final provider = context.read<RoutineProvider>();
  if (provider.routines.isEmpty) {
    await provider.loadRoutines();
  }
  if (!context.mounted) return;

  if (provider.routines.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Crea primero una rutina para añadirle ejercicios.'),
      ),
    );
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RoutineBuilderPage(onSave: provider.loadRoutines),
      ),
    );
    return;
  }

  final routine = provider.routines.first;

  final added = await Navigator.of(context).push<List<Exercise>>(
    MaterialPageRoute(
      builder: (_) =>
          QuickAddPage(dayLabel: hoy, activityType: routine.activityType),
    ),
  );
  if (added == null || added.isEmpty || !context.mounted) return;

  final saved = await provider.addExercisesToDay(routine, hoy, added);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        saved != null
            ? '${added.length} ejercicios añadidos a $hoy.'
            : 'No se pudieron guardar los ejercicios.',
      ),
    ),
  );
}

class _RoutineShortcuts extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _NavTile(
          tile: (
            icon: LucideIcons.clipboardList,
            title: 'Ver mi rutina',
            sub: 'Plan semanal completo por días',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RoutineViewPage()),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _NavTile(
                tile: (
                  icon: LucideIcons.dumbbell,
                  title: 'Constructor',
                  sub: 'Crea tu rutina semanal',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RoutineBuilderPage(
                        onSave: () =>
                            context.read<RoutineProvider>().loadRoutines(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _NavTile(
                tile: (
                  icon: LucideIcons.zap,
                  title: 'Añadir rápido',
                  sub: 'Catálogo con búsqueda',
                  // Abre la alta rápida sobre el día de hoy. Antes caía en la
                  // lista de rutinas, que no tiene nada que ver con "añadir".
                  onTap: () => _openQuickAddForToday(context),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RagBubble extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final summaryProv = context.watch<DailySummaryProvider>();
    final summary = summaryProv.summary;

    String textPart1 =
        'Hola, he analizado tus métricas y estoy listo para guiar tu entrenamiento y nutrición de hoy.';
    String textPart2 = '';

    if (summary != null) {
      if (summary.ultimaSesion != null) {
        textPart1 =
            'He analizado tu última sesión de ${summary.ultimaSesion!.tipoEntrenamiento.toLowerCase()} y ajustado tus métricas. ';
      } else {
        textPart1 = 'He ajustado tus métricas basándome en tu perfil. ';
      }
      if (summary.consumidoHoy.kcal > 0) {
        textPart2 =
            'Llevas ${summary.consumidoHoy.kcal.toInt()} kcal registradas hoy.';
      } else {
        textPart2 = 'Aún no has registrado comidas hoy.';
      }
    }

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
                child: const Icon(
                  LucideIcons.sparkles,
                  size: 12,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'MEMORIA CONTEXTUAL · RAG',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    color: mutedFg,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: fg,
                height: 1.35,
              ),
              children: [
                TextSpan(text: textPart1),
                if (textPart2.isNotEmpty)
                  TextSpan(
                    text: textPart2,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
              ],
            ),
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

  final Map<String, String> _workoutBpms = {};
  final Map<String, int> _workoutKcal = {};

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    final allWorkouts = await HealthService.fetchWorkouts();

    final validWorkouts = allWorkouts.where((w) {
      if (w.value is WorkoutHealthValue) {
        return (w.value as WorkoutHealthValue).workoutActivityType !=
            HealthWorkoutActivityType.WALKING;
      }
      return true;
    }).toList();

    validWorkouts.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));

    if (mounted) {
      setState(() {
        _workouts = validWorkouts;
        _isLoading = false;
      });
    }

    // Load BPMs (y respaldo de calorías) async
    for (var w in validWorkouts.take(4)) {
      final details = await HealthService.fetchWorkoutDetails(
        w.dateFrom,
        w.dateTo,
      );
      final hrData = details['heart_rate'] ?? [];
      final calData = details['calories'] ?? [];

      String? bpm;
      if (hrData.isNotEmpty) {
        final hrValues = hrData
            .map((e) => (e.value as NumericHealthValue).numericValue.toDouble())
            .toList();
        final avg = hrValues.reduce((a, b) => a + b) / hrValues.length;
        bpm = avg.round().toString();
      }

      // `totalEnergyBurned` sale de TOTAL_CALORIES_BURNED; Mi Fitness solo
      // escribe la variante "activa" para estas sesiones — mismo respaldo
      // que en `_TodaySummaryStats` y workout_detail_page.dart.
      int? kcalTotal = (w.value is WorkoutHealthValue)
          ? (w.value as WorkoutHealthValue).totalEnergyBurned
          : null;
      if ((kcalTotal == null || kcalTotal <= 0) && calData.isNotEmpty) {
        final suma = calData
            .where((p) => p.value is NumericHealthValue)
            .fold<double>(
              0,
              (s, p) => s + (p.value as NumericHealthValue).numericValue.toDouble(),
            );
        if (suma > 0) kcalTotal = suma.round();
      }

      final bpmFinal = bpm;
      final kcalFinal = kcalTotal;
      if (mounted && (bpmFinal != null || kcalFinal != null)) {
        setState(() {
          if (bpmFinal != null) _workoutBpms[w.dateFrom.toIso8601String()] = bpmFinal;
          if (kcalFinal != null) _workoutKcal[w.dateFrom.toIso8601String()] = kcalFinal;
        });
      }
    }
  }

  Future<void> _runDiagnostic() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const AlertDialog(
        title: Text('Ejecutando diagnóstico profundo...'),
        content: SizedBox(
          height: 60,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );

    try {
      final diagnosticData = await HealthService.runDiagnostic();
      if (!mounted) return;
      Navigator.pop(context); // cerrar cargando

      String resultText = diagnosticData.entries
          .map((e) => '${e.key}:\n${e.value}\n')
          .join('\n');

      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Diagnóstico HC (90 días)'),
          content: SingleChildScrollView(
            child: Text(
              resultText,
              style: const TextStyle(height: 1.3, fontSize: 13),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('CERRAR'),
            ),
          ],
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
              Text(
                'REGISTROS · MI BAND',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.4,
                  color: mutedFg,
                ),
              ),
              InkWell(
                onTap: _fetchData,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    children: [
                      if (_isLoading)
                        const SizedBox(
                          width: 8,
                          height: 8,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 1.5,
                          ),
                        )
                      else
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF6900),
                            shape: BoxShape.circle,
                          ),
                        ),
                      const SizedBox(width: 4),
                      Text(
                        _isLoading ? 'SINCRONIZANDO' : 'XIAOMI',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Entrenamientos Xiaomi',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
          const SizedBox(height: 24),
          if (_workouts.isEmpty && !_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Column(
                  children: [
                    Text(
                      'No se encontraron entrenamientos.',
                      style: TextStyle(color: mutedFg),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () async {
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

              double dist = 0.0;
              String typeName = 'Entrenamiento';

              if (w.value is WorkoutHealthValue) {
                final workout = w.value as WorkoutHealthValue;
                dist = (workout.totalDistance ?? 0) / 1000;
                typeName = HealthService.translateWorkoutActivityType(
                  workout.workoutActivityType,
                );
              }
              final kcal = _workoutKcal[w.dateFrom.toIso8601String()] ?? 0;

              String desc =
                  '${w.dateFrom.day}/${w.dateFrom.month} · ${w.dateFrom.hour}:${w.dateFrom.minute.toString().padLeft(2, '0')} · $min min';
              if (dist > 0) desc += ' · ${dist.toStringAsFixed(1)} km';

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => WorkoutDetailPage(workout: w),
                      ),
                    );
                  },
                  child: _WorkoutRow(
                    icon: LucideIcons.activity,
                    title: typeName,
                    desc: desc,
                    bpm: _workoutBpms[w.dateFrom.toIso8601String()] ?? '--',
                    kcal: kcal > 0 ? '$kcal' : '--',
                  ),
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
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                desc,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: mutedFg),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: fg,
                ),
                children: [
                  TextSpan(text: bpm),
                  TextSpan(
                    text: 'bpm',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: mutedFg,
                    ),
                  ),
                ],
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

/* ============================== NUTRICIÓN ============================== */

class _NutritionScreen extends StatefulWidget {
  const _NutritionScreen({required this.onOpen});
  final VoidCallback onOpen;

  @override
  State<_NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<_NutritionScreen> {
  bool _isLoadingAi = false;
  bool _isSavingScan = false;
  Map<String, dynamic>? _lastScan;
  Map<String, dynamic>? _pendingScan;
  final _msgController = TextEditingController();

  @override
  void dispose() {
    _msgController.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    // Dentro del try y con reescalado, igual que en Clínica y Físico: una foto
    // de cámara sin comprimir son varios MB, y en base64 crece otro 33 % sin
    // que el modelo lea mejor el plato. Fuera del try, un fallo de cámara
    // (`no_available_camera`) se perdía sin que el usuario viera nada.
    final XFile? file;
    try {
      file = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        imageQuality: 85,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains('no_available_camera')
                ? 'No se ha podido abrir la cámara en este dispositivo.'
                : 'No se ha podido tomar la foto: $e',
          ),
        ),
      );
      return;
    }
    if (file == null) return;

    if (!mounted) return;
    setState(() {
      _isLoadingAi = true;
      _pendingScan = null;
    });

    try {
      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);
      final userId = ApiService.getCurrentUserId() ?? '';
      final userMessage = _msgController.text.trim();

      String finalPrompt =
          'Analiza esta comida de forma semántica y holística. Identifica componentes, estima macros (proteína, carbohidratos, grasas en gramos) y calorías basándote en el volumen visual. Añade en "notas" unas pequeñas conclusiones de MÁXIMO 2 ORACIONES (ej. nivel NOVA o impacto glucémico).';
      if (userMessage.isNotEmpty) {
        finalPrompt +=
            '\n\nMensaje adicional del usuario que debes tener en cuenta al estimar: "$userMessage"';
      }

      final response = await ApiService.sendChatMessage(
        userId: userId,
        mode: 'nutricion',
        message: finalPrompt,
        images: [
          {'data': base64Image, 'mimeType': file.mimeType ?? 'image/jpeg'},
        ],
      );

      final actionsTaken = response['actions_taken'] as List<dynamic>? ?? [];
      Map<String, dynamic>? estimate;
      Map<String, dynamic>? savedResult;
      for (final action in actionsTaken) {
        if (action is! Map<String, dynamic>) continue;
        if (action['tool'] == 'estimar_comida') {
          estimate = action['result'] as Map<String, dynamic>?;
        } else if (action['tool'] == 'registrar_comida') {
          savedResult = action['result'] as Map<String, dynamic>?;
        }
      }

      if (savedResult != null) {
        // El modelo guardó directo (turno de confirmación por texto en un chat
        // previo) — ya está en BD, no hace falta pasar por el botón de confirmar.
        _lastScan = savedResult;
        if (mounted) {
          await context.read<DailySummaryProvider>().load();
        }
      } else if (estimate != null) {
        setState(() => _pendingScan = estimate);
      } else if (mounted) {
        final reply = response['reply']?.toString() ?? '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              reply.isNotEmpty
                  ? reply
                  : 'No se pudo identificar la comida en la foto.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error procesando imagen: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingAi = false);
      }
    }
  }

  Future<void> _confirmPendingScan() async {
    final scan = _pendingScan;
    if (scan == null || _isSavingScan) return;
    setState(() => _isSavingScan = true);
    try {
      final userId = ApiService.getCurrentUserId() ?? '';
      final now = DateTime.now();
      final fechaRegistro =
          '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
      final saved = await ApiService.createNutritionLog(
        userId: userId,
        fechaRegistro: fechaRegistro,
        caloriasConsumidas:
            (scan['calorias_consumidas'] as num?)?.toInt() ?? 0,
        proteinasG: (scan['proteinas_g'] as num?)?.toDouble() ?? 0.0,
        carbohidratosG: (scan['carbohidratos_g'] as num?)?.toDouble() ?? 0.0,
        grasasG: (scan['grasas_g'] as num?)?.toDouble() ?? 0.0,
        notas: scan['notas']?.toString(),
        tipoComida: scan['tipo_comida']?.toString(),
        nombreAlimento: scan['nombre_alimento']?.toString(),
      );
      if (!mounted) return;
      setState(() {
        _lastScan = saved;
        _pendingScan = null;
      });
      await context.read<DailySummaryProvider>().load();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Comida guardada.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar la comida: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingScan = false);
      }
    }
  }

  void _discardPendingScan() {
    setState(() => _pendingScan = null);
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MacrosOverview(),
          const SizedBox(height: 16),
          const ManualFoodEntryCard(),
          const SizedBox(height: 16),
          const TodaysMealsCard(),
          const SizedBox(height: 16),
          const HydrationCard(),
          const SizedBox(height: 16),
          const SupplementsCard(),
          const SizedBox(height: 16),
          TextField(
            controller: _msgController,
            decoration: InputDecoration(
              hintText: 'Añadir contexto (ej. "plato grande, mucha salsa")',
              filled: true,
              fillColor: DesignTokens.surface2of(b),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            style: TextStyle(color: DesignTokens.foreground(b)),
          ),
          const SizedBox(height: 16),
          _isLoadingAi
              ? Container(
                  height: 240,
                  decoration: BoxDecoration(
                    color: DesignTokens.card(b),
                    borderRadius: BorderRadius.circular(
                      DesignTokens.cardRadius,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        'Procesando ingredientes...',
                        style: TextStyle(
                          color: DesignTokens.foreground(b),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Red neuronal multicapa',
                        style: TextStyle(
                          color: DesignTokens.mutedForeground(b),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                )
              : _CameraViewer(onTap: _takePhoto),
          const SizedBox(height: 16),
          if (_pendingScan != null)
            _ScanResultCard(
              scanResult: _pendingScan,
              pending: true,
              isSaving: _isSavingScan,
              onConfirm: _confirmPendingScan,
              onDiscard: _discardPendingScan,
            )
          else
            _ScanResultCard(scanResult: _lastScan),
          const SizedBox(height: 16),
          _NavTile(
            tile: (
              icon: LucideIcons.trendingUp,
              title: 'Ver calendario de nutrición',
              sub: 'Historial diario de kcal y macros',
              onTap: () => Navigator.pushNamed(context, '/progress'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Anillo de kcal: pista completa + arco de progreso con el gradiente IA,
/// arrancando a las 12 en punto.
class _KcalDialPainter extends CustomPainter {
  const _KcalDialPainter({required this.pct, required this.track});
  final double pct;
  final Color track;

  static const _stroke = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - (_stroke / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke,
    );

    if (pct <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * pct,
      false,
      Paint()
        ..shader = DesignTokens.aiGradient.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_KcalDialPainter old) =>
      old.pct != pct || old.track != track;
}

class _MacrosOverview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final card = DesignTokens.card(b);
    final fg = DesignTokens.foreground(b);
    final mutedFg = DesignTokens.mutedForeground(b);

    final summary = context.watch<DailySummaryProvider>().summary;
    final obj = summary?.objetivos;
    final cons = summary?.consumidoHoy;

    final tkcal = obj?.kcal.toInt() ?? 2000;
    final ckcal = cons?.kcal.toInt() ?? 0;
    final fkcal = ((tkcal - ckcal).clamp(0, 9999)).toInt();
    final pctKcal = tkcal > 0 ? (ckcal / tkcal).clamp(0.0, 1.0) : 0.0;

    final tprot = obj?.proteinasG.toInt() ?? 150;
    final cprot = cons?.proteinasG.toInt() ?? 0;

    final tcarb = obj?.carbohidratosG.toInt() ?? 200;
    final ccarb = cons?.carbohidratosG.toInt() ?? 0;

    final tfat = obj?.grasasG.toInt() ?? 70;
    final cfat = cons?.grasasG.toInt() ?? 0;

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
                  Text(
                    'HOY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                      color: mutedFg,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tus macros',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: fg,
                    ),
                  ),
                ],
              ),
              // Arco proporcional a lo consumido, no un borde fijo: el número
              // dice cuánto queda, el anillo dice cuánto se lleva.
              SizedBox(
                width: 72,
                height: 72,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(72, 72),
                      painter: _KcalDialPainter(
                        pct: pctKcal,
                        track: DesignTokens.muted(b),
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$fkcal',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: fg,
                            height: 1.0,
                          ),
                        ),
                        Text(
                          'RESTAN',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: mutedFg,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _MacroRow(
            label: 'Proteína',
            val: cprot,
            total: tprot,
            color: const Color(0xFF9D7BFF),
            fg: fg,
            mutedFg: mutedFg,
            muted: DesignTokens.muted(b),
          ),
          const SizedBox(height: 16),
          _MacroRow(
            label: 'Carbohidratos',
            val: ccarb,
            total: tcarb,
            color: const Color(0xFF06B6D4),
            fg: fg,
            mutedFg: mutedFg,
            muted: DesignTokens.muted(b),
          ),
          const SizedBox(height: 16),
          _MacroRow(
            label: 'Grasas',
            val: cfat,
            total: tfat,
            color: const Color(0xFFF87171),
            fg: fg,
            mutedFg: mutedFg,
            muted: DesignTokens.muted(b),
          ),
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
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
                children: [
                  TextSpan(text: '$val', style: const TextStyle(fontSize: 13)),
                  TextSpan(
                    text: ' / ${total}g',
                    style: TextStyle(
                      color: mutedFg,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  TextSpan(
                    text: ' · faltan ${faltan}g',
                    style: TextStyle(
                      color: mutedFg,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: muted,
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: pct,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
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
                    child: const Icon(
                      LucideIcons.camera,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Fotografía tu comida',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Visión MLLM · sin inputs manuales',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
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
                      border: Border.all(
                        color: Colors.white.withOpacity(0.4),
                        width: 4,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        gradient: DesignTokens.aiGradient,
                        shape: BoxShape.circle,
                      ),
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
          left: left
              ? const BorderSide(color: Color(0xCCFFFFFF), width: 2)
              : BorderSide.none,
          top: top
              ? const BorderSide(color: Color(0xCCFFFFFF), width: 2)
              : BorderSide.none,
          right: !left
              ? const BorderSide(color: Color(0xCCFFFFFF), width: 2)
              : BorderSide.none,
          bottom: !top
              ? const BorderSide(color: Color(0xCCFFFFFF), width: 2)
              : BorderSide.none,
        ),
        borderRadius: BorderRadius.only(
          topLeft: (left && top) ? const Radius.circular(12) : Radius.zero,
          topRight: (!left && top) ? const Radius.circular(12) : Radius.zero,
          bottomLeft: (left && !top) ? const Radius.circular(12) : Radius.zero,
          bottomRight: (!left && !top)
              ? const Radius.circular(12)
              : Radius.zero,
        ),
      ),
    );
  }
}

class _ScanResultCard extends StatelessWidget {
  const _ScanResultCard({
    this.scanResult,
    this.pending = false,
    this.isSaving = false,
    this.onConfirm,
    this.onDiscard,
  });
  final Map<String, dynamic>? scanResult;

  /// Si es `true`, esta estimación todavía no está guardada en BD: la
  /// tarjeta muestra los botones de confirmar/descartar en vez de tratarla
  /// como un registro histórico.
  final bool pending;
  final bool isSaving;
  final VoidCallback? onConfirm;
  final VoidCallback? onDiscard;

  @override
  Widget build(BuildContext context) {
    if (scanResult == null) return const SizedBox.shrink();

    final b = Theme.of(context).brightness;
    final card = DesignTokens.card(b);
    final fg = DesignTokens.foreground(b);
    final mutedFg = DesignTokens.mutedForeground(b);
    final surface1 = DesignTokens.surface1(b);
    final muted = DesignTokens.muted(b);

    final foodName =
        scanResult?['nombre_alimento']?.toString() ?? 'Análisis completado';
    final notas = scanResult?['notas']?.toString() ?? '';
    final p = (scanResult?['proteinas_g'] as num?)?.toDouble() ?? 0.0;
    final c = (scanResult?['carbohidratos_g'] as num?)?.toDouble() ?? 0.0;
    final f = (scanResult?['grasas_g'] as num?)?.toDouble() ?? 0.0;
    final kcal = (scanResult?['calorias_consumidas'] as num?)?.toInt() ?? 0;

    // Reparto calórico de la comida (proteína y carbos 4 kcal/g, grasa 9 kcal/g).
    // Las tres barras suman el 100% del aporte energético de este plato.
    final kcalP = p * 4, kcalC = c * 4, kcalF = f * 9;
    final kcalMacros = kcalP + kcalC + kcalF;
    double share(double parte) =>
        kcalMacros > 0 ? (parte / kcalMacros).clamp(0.0, 1.0) : 0.0;

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
          Text(
            pending ? 'Confirma esta comida' : 'Última Comida Escaneada',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: fg,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$foodName · $kcal kcal',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: mutedFg,
            ),
          ),
          if (notas.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: DesignTokens.aiVia.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: DesignTokens.aiVia.withOpacity(0.2)),
              ),
              child: Text(
                notas,
                style: TextStyle(fontSize: 13, color: fg, height: 1.4),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MacroChip(
                  label: 'Proteína',
                  value: '${p.toInt()}g',
                  pct: share(kcalP),
                  fg: fg,
                  mutedFg: mutedFg,
                  surface1: surface1,
                  muted: muted,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MacroChip(
                  label: 'Carbos',
                  value: '${c.toInt()}g',
                  pct: share(kcalC),
                  fg: fg,
                  mutedFg: mutedFg,
                  surface1: surface1,
                  muted: muted,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MacroChip(
                  label: 'Grasas',
                  value: '${f.toInt()}g',
                  pct: share(kcalF),
                  fg: fg,
                  mutedFg: mutedFg,
                  surface1: surface1,
                  muted: muted,
                ),
              ),
            ],
          ),
          if (pending) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isSaving ? null : onDiscard,
                    child: const Text('Descartar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: isSaving ? null : onConfirm,
                    child: isSaving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text('Confirmar e insertar'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MacroChip extends StatelessWidget {
  const _MacroChip({
    required this.label,
    required this.value,
    required this.pct,
    required this.fg,
    required this.mutedFg,
    required this.surface1,
    required this.muted,
  });
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
      decoration: BoxDecoration(
        color: surface1,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
              color: mutedFg,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: muted,
              valueColor: const AlwaysStoppedAnimation<Color>(
                DesignTokens.aiVia,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ============================== CLÍNICA ============================== */

class _HealthScreen extends StatelessWidget {
  const _HealthScreen();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HealthHubGrid(),
          const SizedBox(height: 24),
          const _ComposicionSalud(),
          const SizedBox(height: 16),
          const _PosturaSalud(),
          const SizedBox(height: 16),
          _SeccionCard(child: HealthRecordsHistory()),
        ],
      ),
    );
  }
}

/// Envoltorio visual común (tarjeta blanca + sombra) para las secciones de
/// Salud que no lo traen ya incluido en su propio widget.
class _SeccionCard extends StatelessWidget {
  const _SeccionCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DesignTokens.card(b),
        borderRadius: BorderRadius.circular(DesignTokens.cardRadius),
        boxShadow: DesignTokens.shadowCard(b),
      ),
      child: child,
    );
  }
}

/// Composición corporal real, de las mediciones que el usuario registró en
/// Clínica (báscula, DEXA, bioimpedancia…). Antes esta tarjeta enseñaba una
/// curva de 6 meses inventada (`lean`/`fat` con valores fijos en el código):
/// aquí va la evolución real de porcentaje de grasa, con los datos que de
/// verdad hay.
class _ComposicionSalud extends StatefulWidget {
  const _ComposicionSalud();

  @override
  State<_ComposicionSalud> createState() => _ComposicionSaludState();
}

class _ComposicionSaludState extends State<_ComposicionSalud> {
  List<Map<String, dynamic>>? _mediciones;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final userId = ApiService.getCurrentUserId();
    if (userId == null) return;
    try {
      final lista = await ApiService.getDexaScansByUser(userId);
      if (!mounted) return;
      setState(() => _mediciones = lista);
    } catch (_) {
      if (!mounted) return;
      setState(() => _mediciones = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final mediciones = _mediciones;

    if (mediciones == null) {
      return const _SeccionCard(
        child: SizedBox(
          height: 80,
          child: Center(
            child: SizedBox(
                width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2)),
          ),
        ),
      );
    }

    if (mediciones.isEmpty) {
      return _SeccionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('COMPOSICIÓN CORPORAL',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.4,
                    color: DesignTokens.mutedForeground(b))),
            const SizedBox(height: 8),
            Text(
              'Todavía no hay ninguna medición registrada. Es el dato que más '
              'usa la IA para calcular calorías y macros.',
              style: TextStyle(fontSize: 13, color: DesignTokens.mutedForeground(b)),
            ),
            const SizedBox(height: 14),
            _BotonIrAClinica(label: 'Registrar composición'),
          ],
        ),
      );
    }

    // Más reciente primero desde el backend: se invierte para dibujar la
    // curva en orden cronológico.
    final cronologico = mediciones.reversed.toList();
    final ultima = mediciones.first;
    final grasaSerie = [
      for (final m in cronologico)
        if (m['porcentaje_grasa'] != null) (num.parse('${m['porcentaje_grasa']}')).toDouble(),
    ];

    return _SeccionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('COMPOSICIÓN CORPORAL',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.4,
                        color: DesignTokens.mutedForeground(b))),
              ),
              Text(readableDate(ultima['fecha_escaneo']),
                  style: TextStyle(fontSize: 11, color: DesignTokens.mutedForeground(b))),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final celda in <(String, String)>[
                ('Peso', _cifra(ultima['peso_kg'], 'kg')),
                ('IMC', _cifra(ultima['imc'], '')),
                ('Grasa', _cifra(ultima['porcentaje_grasa'], '%')),
                ('M. magra', _cifra(ultima['masa_magra_kg'], 'kg')),
              ])
                Expanded(
                  child: Column(
                    children: [
                      Text(celda.$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: DesignTokens.foreground(b))),
                      const SizedBox(height: 2),
                      Text(celda.$1,
                          style: TextStyle(
                              fontSize: 10, color: DesignTokens.mutedForeground(b))),
                    ],
                  ),
                ),
            ],
          ),
          if (grasaSerie.length >= 2) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 70,
              child: CustomPaint(
                size: Size.infinite,
                painter: _TendenciaPainter(valores: grasaSerie, color: DesignTokens.aiVia),
              ),
            ),
            const SizedBox(height: 6),
            Text('% de grasa · últimas ${grasaSerie.length} mediciones',
                style: TextStyle(fontSize: 10.5, color: DesignTokens.mutedForeground(b))),
          ],
        ],
      ),
    );
  }
}

String _cifra(dynamic valor, String unidad) {
  if (valor == null) return '—';
  final n = valor is num ? valor : num.tryParse('$valor');
  if (n == null) return '—';
  final texto = n == n.roundToDouble() ? n.toStringAsFixed(0) : n.toStringAsFixed(1);
  return unidad.isEmpty ? texto : '$texto$unidad';
}

class _BotonIrAClinica extends StatelessWidget {
  const _BotonIrAClinica({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => Navigator.pushNamed(context, '/clinic/import'),
        icon: const Icon(LucideIcons.plus, size: 16),
        label: Text(label),
      ),
    );
  }
}

/// Línea simple con relleno degradado, a partir de datos reales — sustituye a
/// `_CompPainter`, que dibujaba dos curvas con valores fijos en el código
/// (`[40, 42, 43, 45, 46, 48, 49]`) sin relación con el usuario que las veía.
class _TendenciaPainter extends CustomPainter {
  const _TendenciaPainter({required this.valores, required this.color});
  final List<double> valores;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final min = valores.reduce((a, b) => a < b ? a : b);
    final max = valores.reduce((a, b) => a > b ? a : b);
    // Rango con un margen del 15% para que la línea no toque los bordes; si
    // todos los valores son iguales, un rango de 1 evita dividir por 0.
    final rango = (max - min) <= 0 ? 1.0 : (max - min) * 1.15;
    final base = (max + min) / 2 - rango / 2;

    final w = size.width, h = size.height;
    Path trazo() {
      final p = Path();
      for (var i = 0; i < valores.length; i++) {
        final x = valores.length == 1 ? 0.0 : (i / (valores.length - 1)) * w;
        final y = h - ((valores[i] - base) / rango) * h;
        if (i == 0) {
          p.moveTo(x, y);
        } else {
          p.lineTo(x, y);
        }
      }
      return p;
    }

    final linea = trazo();
    final relleno = Path.from(linea)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    final grad = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [color.withOpacity(0.30), color.withOpacity(0)],
    ).createShader(Offset.zero & size);
    canvas.drawPath(relleno, Paint()..shader = grad..style = PaintingStyle.fill);
    canvas.drawPath(
      linea,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _TendenciaPainter old) =>
      old.valores != valores || old.color != color;
}

/// Postura real: lo que la IA observó en las fotos que subió el usuario al
/// apartado Físico, no una malla 3D decorativa con un "-38%" fijo en el
/// código. `postura_observaciones` es texto libre (no hay un score numérico
/// de asimetría en el pipeline real), así que se enseña como texto, con el
/// histórico real de capturas debajo.
class _PosturaSalud extends StatefulWidget {
  const _PosturaSalud();

  @override
  State<_PosturaSalud> createState() => _PosturaSaludState();
}

class _PosturaSaludState extends State<_PosturaSalud> {
  List<Map<String, dynamic>>? _registros;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final userId = ApiService.getCurrentUserId();
    if (userId == null) return;
    try {
      final lista = await ApiService.getBodyAnalysisRecords(userId);
      lista.sort((a, b) => (b['fecha_analisis']?.toString() ?? '')
          .compareTo(a['fecha_analisis']?.toString() ?? ''));
      if (!mounted) return;
      setState(() => _registros = lista);
    } catch (_) {
      if (!mounted) return;
      setState(() => _registros = []);
    }
  }

  Future<void> _nuevaCaptura() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AiCoachPage(initialMode: ChatMode.analisisFisico),
      ),
    );
    if (!mounted) return;
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final registros = _registros;

    if (registros == null) {
      return const _SeccionCard(
        child: SizedBox(
          height: 80,
          child: Center(
            child: SizedBox(
                width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2)),
          ),
        ),
      );
    }

    final ultimo = registros.isNotEmpty ? registros.first : null;
    final observaciones = reportText(ultimo?['postura_observaciones']);
    final prioridad = reportText(ultimo?['prioridad_entrenamiento']);

    return _SeccionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('POSTURA · ANÁLISIS POR FOTOS',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.4,
                  color: DesignTokens.mutedForeground(b))),
          const SizedBox(height: 8),
          if (ultimo == null)
            Text(
              'Todavía no hay ningún análisis del físico. Sube fotos para que '
              'la IA describa tu postura y la vaya siguiendo en el tiempo.',
              style: TextStyle(fontSize: 13, color: DesignTokens.mutedForeground(b)),
            )
          else ...[
            Text(
              observaciones.isEmpty
                  ? 'Sin observaciones de postura en el último análisis '
                      '(${readableDate(ultimo['fecha_analisis'])}).'
                  : observaciones,
              style: TextStyle(
                  fontSize: 13.5, height: 1.4, color: DesignTokens.foreground(b)),
            ),
            if (prioridad.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(LucideIcons.target, size: 15, color: DesignTokens.aiVia),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(prioridad,
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: DesignTokens.foreground(b))),
                  ),
                ],
              ),
            ],
          ],
          const SizedBox(height: 16),
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: _nuevaCaptura,
              borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
              child: Ink(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: DesignTokens.aiGradient,
                  borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.camera, size: 17, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Tomar nueva imagen',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14.5)),
                  ],
                ),
              ),
            ),
          ),
          if (registros.length > 1) ...[
            const SizedBox(height: 20),
            Text('HISTÓRICO DE CAPTURAS',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.4,
                    color: DesignTokens.mutedForeground(b))),
            const SizedBox(height: 10),
            for (var i = 0; i < registros.length && i < 6; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _CapturaRow(registro: registros[i], esActual: i == 0),
            ],
          ],
        ],
      ),
    );
  }
}

/// Fila del histórico real de análisis del físico.
class _CapturaRow extends StatelessWidget {
  const _CapturaRow({required this.registro, required this.esActual});
  final Map<String, dynamic> registro;
  final bool esActual;

  static const _meses = [
    'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
    'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
  ];

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final fecha = DateTime.tryParse(registro['fecha_analisis']?.toString() ?? '');
    final mes = fecha != null ? _meses[fecha.month - 1] : '—';
    final dia = fecha != null ? fecha.day.toString().padLeft(2, '0') : '—';
    final numFotos = registro['num_fotos'];
    final detalle = reportText(registro['postura_observaciones']).isNotEmpty
        ? reportText(registro['postura_observaciones'])
        : (numFotos is num && numFotos > 0
            ? '${numFotos.toStringAsFixed(0)} foto(s) analizadas'
            : 'Sin observaciones de postura');

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: DesignTokens.surface1(b),
        borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: DesignTokens.card(b),
              borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(mes,
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: DesignTokens.mutedForeground(b))),
                Text(dia,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        height: 1,
                        color: DesignTokens.foreground(b))),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Análisis $mes',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: DesignTokens.foreground(b))),
                Text(detalle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: DesignTokens.mutedForeground(b))),
              ],
            ),
          ),
          if (esActual)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: DesignTokens.success(b).withOpacity(0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('Actual',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: DesignTokens.success(b))),
            )
          else
            Icon(LucideIcons.chevronRight, size: 16, color: DesignTokens.mutedForeground(b)),
        ],
      ),
    );
  }
}

/* ============================== BOTTOM NAV ============================== */

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.active, required this.onChange});

  final String active;
  final ValueChanged<String> onChange;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('dashboard', 'Inicio', LucideIcons.home),
      ('coach', 'Entrenar', LucideIcons.dumbbell),
      ('nutrition', 'Nutrición', LucideIcons.apple),
      ('progress', 'Progreso', LucideIcons.trendingUp),
      ('health', 'Salud', LucideIcons.heart),
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
            final mutedFg = DesignTokens.mutedForeground(
              Theme.of(context).brightness,
            );
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
                      AiGradientText(
                        it.$2,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isActive ? fg : mutedFg,
                        ),
                      ),
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
