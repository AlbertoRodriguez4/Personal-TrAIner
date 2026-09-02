import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/workout_session_provider.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../services/api_service.dart';
import '../../../../services/notification_service.dart';
import '../../../../services/ble_service.dart';
import '../../models/exercise.dart';
import '../../models/routine.dart';
import '../widgets/routine_day_picker.dart';
import 'routines_home_page.dart';

class WorkoutSessionPage extends StatefulWidget {
  const WorkoutSessionPage({
    super.key,
    required this.routine,
    this.dayIndex,
    this.reanudar,
  });

  final Routine routine;

  /// Resumen de una sesión sin terminar. Si viene, la sesión se retoma por
  /// donde iba en vez de empezar de cero, y `dayIndex` se ignora: el día lo
  /// dice el propio resumen.
  final Map<String, dynamic>? reanudar;

  /// Día de la rutina con el que arrancar. `null` = el planificado para hoy
  /// (`indiceDiaPorDefecto`), que es lo que se quiere el 99 % de las veces.
  ///
  /// Que sea explícito importa: `WorkoutSessionProvider.startSession` declara
  /// `dayIndex = 0` y ninguna de las dos pantallas que abren una sesión le
  /// pasaba nada, así que la sesión empezaba SIEMPRE por el primer día de la
  /// rutina. Un jueves, el botón decía "Iniciar Pierna" y dentro salía el
  /// pecho del lunes.
  final int? dayIndex;

  @override
  State<WorkoutSessionPage> createState() => _WorkoutSessionPageState();
}

class _WorkoutSessionPageState extends State<WorkoutSessionPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<WorkoutSessionProvider>();
      final aReanudar = widget.reanudar;
      if (aReanudar != null) {
        p.reanudarSesion(widget.routine, aReanudar);
      } else {
        p.startSession(
          widget.routine,
          dayIndex: widget.dayIndex ?? indiceDiaPorDefecto(widget.routine),
        );
      }
      if (p.connectionLabel == null) p.connectWatch();
      p.onWorkoutDetected = _onWorkoutDetected;
      // El permiso de notificaciones solo se pedía desde el perfil, al activar
      // los recordatorios. Quien no pasara por ahí entrenaba sin ver nunca la
      // notificación de sesión, sin que nada se lo explicase. Empezar un
      // entrenamiento es el momento natural para pedirlo, y Android solo
      // muestra el diálogo la primera vez: después esto no interrumpe nada.
      _comprobarNotificaciones();
    });
  }

  /// Pide el permiso y, si no hay notificación, DICE por qué. Antes esto era
  /// un `unawaited(...).catchError((_) => false)`: sin permiso o con el plugin
  /// fallando, no aparecía nada y nada lo explicaba, que es indistinguible de
  /// que la función no exista.
  Future<void> _comprobarNotificaciones() async {
    bool concedido;
    try {
      concedido = await NotificationService.pedirPermiso();
    } catch (e) {
      NotificationService.ultimoFallo = e.toString();
      concedido = false;
    }
    if (!mounted) return;

    final fallo = NotificationService.ultimoFallo;
    if (fallo != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Las notificaciones fallaron: $fallo'),
          duration: const Duration(seconds: 8),
        ),
      );
      return;
    }
    if (!concedido) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sin permiso de notificaciones no se puede mostrar el '
            'entrenamiento en la barra. Actívalo en los ajustes del sistema.',
          ),
          duration: Duration(seconds: 6),
        ),
      );
    }
  }

  void _onWorkoutDetected() {
    if (!mounted) return;
    final p = context.read<WorkoutSessionProvider>();
    if (p.phase != Phase.idle && p.phase != Phase.finished) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Frecuencia cardíaca elevada sostenida. ¿Quieres registrar un entrenamiento?',
        ),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Registrar',
          onPressed: () {
            p.dismissWorkoutDetection();
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    final p = context.read<WorkoutSessionProvider>();
    p.onWorkoutDetected = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: context.read<WorkoutSessionProvider>(),
      child: Consumer<WorkoutSessionProvider>(
        builder: (context, p, _) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: SafeArea(
              child: p.phase == Phase.finished
                  ? _SummaryView(provider: p)
                  : _SessionBody(provider: p, routineName: widget.routine.name),
            ),
            bottomNavigationBar:
                p.phase == Phase.finished ? null : _FinishBar(provider: p),
          );
        },
      ),
    );
  }
}

class _SessionBody extends StatelessWidget {
  const _SessionBody({required this.provider, required this.routineName});
  final WorkoutSessionProvider provider;
  final String routineName;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        _SessionHeader(provider: provider, routineName: routineName),
        const SizedBox(height: 16),
        _ConnectionBar(provider: provider),
        const SizedBox(height: 16),
        _TimerCard(provider: provider),
        const SizedBox(height: 16),
        _HrCard(provider: provider),
        const SizedBox(height: 16),
        _ExerciseChecklist(provider: provider),
        const SizedBox(height: 16),
        if (provider.currentExercise != null) _ExerciseCard(provider: provider),
        const SizedBox(height: 16),
        _PhaseControls(provider: provider),
        const SizedBox(height: 16),
        if (provider.results.isNotEmpty)
          _RecentResults(provider: provider),
      ],
    );
  }
}

class _SessionHeader extends StatelessWidget {
  const _SessionHeader({required this.provider, required this.routineName});
  final WorkoutSessionProvider provider;
  final String routineName;

  /// Cambiar de día solo mientras no se haya entrenado nada: `startSession`
  /// limpia series, resultados y cronómetro, así que a mitad de sesión esto
  /// sería un borrado de progreso disfrazado de cambio de día.
  bool get _puedeCambiarDia =>
      provider.phase == Phase.idle &&
      provider.results.isEmpty &&
      (provider.routine?.days.length ?? 0) > 1;

  Future<void> _cambiarDia(BuildContext context) async {
    final routine = provider.routine;
    if (routine == null) return;
    final elegido = await showRoutineDayPicker(
      context,
      routine,
      seleccionado: provider.dayIndex,
    );
    if (elegido == null || elegido == provider.dayIndex) return;
    provider.startSession(routine, dayIndex: elegido);
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final day = provider.currentDay;
    final eyebrow =
        day != null ? '${day.dayOfWeek} · sesión en vivo' : 'Sesión en vivo';
    final title = day?.focus ?? routineName;
    final paused = provider.paused;

    return Row(
      children: [
        Material(
          color: DesignTokens.surface1(b),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => provider.endSession(),
            child: Padding(
              padding: const EdgeInsets.all(9),
              child: Icon(LucideIcons.arrowLeft,
                  size: 18, color: DesignTokens.foreground(b)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      eyebrow,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DesignTokens.labelSmall(
                          color: DesignTokens.mutedForeground(b)),
                    ),
                  ),
                  if (_puedeCambiarDia) ...[
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => _cambiarDia(context),
                      borderRadius: BorderRadius.circular(999),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.calendarDays,
                                size: 12,
                                color: DesignTokens.mutedForeground(b)),
                            const SizedBox(width: 4),
                            Text(
                              'Cambiar',
                              style: DesignTokens.labelSmall(
                                  color: DesignTokens.mutedForeground(b)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: paused
                ? DesignTokens.surface1(b)
                : DesignTokens.success(b).withOpacity(0.14),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            paused ? 'En pausa' : 'En curso',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: paused
                  ? DesignTokens.mutedForeground(b)
                  : DesignTokens.success(b),
            ),
          ),
        ),
      ],
    );
  }
}

class _TimerCard extends StatelessWidget {
  const _TimerCard({required this.provider});
  final WorkoutSessionProvider provider;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final total = provider.totalExercisesInDay;
    final completed = provider.completedExercisesCount;
    final pct = total == 0 ? 0.0 : completed / total;
    final paused = provider.paused;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DesignTokens.card(b),
        borderRadius: BorderRadius.circular(DesignTokens.cardRadius),
        boxShadow: DesignTokens.shadowCard(b),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TIEMPO DE SESIÓN',
                        style: DesignTokens.labelSmall(
                            color: DesignTokens.mutedForeground(b))),
                    Text(
                      provider.sessionElapsedFormatted,
                      style: DesignTokens.titleFont(
                        fontSize: 40,
                        color: DesignTokens.foreground(b),
                        letterSpacing: -1,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('PROGRESO',
                      style: DesignTokens.labelSmall(
                          color: DesignTokens.mutedForeground(b))),
                  Text(
                    '$completed/$total',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: DesignTokens.surface1(b),
              valueColor: AlwaysStoppedAnimation(DesignTokens.aiVia),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  icon: LucideIcons.heart,
                  label: 'FC',
                  value: '${provider.currentBpm}',
                  unit: 'bpm',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniStat(
                  icon: LucideIcons.flame,
                  label: 'Kcal',
                  value: '${provider.estimatedKcal}',
                  unit: '',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniStat(
                  icon: LucideIcons.clock,
                  label: 'Descanso',
                  value: provider.phase == Phase.rest
                      ? '${provider.restRemaining}'
                      : '—',
                  unit: provider.phase == Phase.rest ? 's' : '',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => paused
                        ? provider.resumeSession()
                        : provider.pauseSession(),
                    icon: Icon(paused ? LucideIcons.play : LucideIcons.pause,
                        size: 18),
                    label: Text(paused ? 'Reanudar sesión' : 'Pausar sesión'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DesignTokens.aiVia,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(DesignTokens.radiusXl),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 52,
                height: 52,
                child: OutlinedButton(
                  onPressed: () => provider.restartSession(),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
                    ),
                    side: BorderSide(color: DesignTokens.border(b)),
                  ),
                  child: Icon(LucideIcons.rotateCcw,
                      size: 18, color: DesignTokens.mutedForeground(b)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
  });
  final IconData icon;
  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DesignTokens.surface1(b),
        borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: DesignTokens.mutedForeground(b)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: DesignTokens.labelSmall(
                      color: DesignTokens.mutedForeground(b), fontSize: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: DesignTokens.titleFont(
                    fontSize: 18, color: DesignTokens.foreground(b)),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 2),
                Text(unit,
                    style: TextStyle(
                        fontSize: 10, color: DesignTokens.mutedForeground(b))),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _FinishBar extends StatelessWidget {
  const _FinishBar({required this.provider});
  final WorkoutSessionProvider provider;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final total = provider.totalExercisesInDay;
    final completed = provider.completedExercisesCount;
    final finished = total > 0 && completed == total;

    return Material(
      color: DesignTokens.background(b),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              gradient: finished ? DesignTokens.aiGradient : null,
              color: finished ? null : DesignTokens.surface1(b),
              borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
                onTap: finished ? () => provider.endSession() : null,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.checkCircle2,
                        size: 18,
                        color: finished
                            ? Colors.white
                            : DesignTokens.mutedForeground(b),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        finished
                            ? 'Finalizar entrenamiento'
                            : 'Faltan ${total - completed} ejercicios',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: finished
                              ? Colors.white
                              : DesignTokens.mutedForeground(b),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExerciseChecklist extends StatelessWidget {
  const _ExerciseChecklist({required this.provider});
  final WorkoutSessionProvider provider;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final day = provider.currentDay;
    if (day == null || day.exercises.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: DesignTokens.card(b),
        borderRadius: BorderRadius.circular(DesignTokens.cardRadius),
        boxShadow: DesignTokens.shadowCard(b),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('EJERCICIOS',
              style: DesignTokens.labelSmall(
                  color: DesignTokens.mutedForeground(b))),
          const SizedBox(height: 10),
          for (var i = 0; i < day.exercises.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _ChecklistRow(
                provider: provider, index: i, exercise: day.exercises[i]),
          ],
        ],
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({
    required this.provider,
    required this.index,
    required this.exercise,
  });
  final WorkoutSessionProvider provider;
  final int index;
  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final done = provider.isExerciseDone(index);
    final current = index == provider.exerciseIndex && !done;
    final meta = [
      if (exercise.sets != null && exercise.reps != null)
        '${exercise.sets} × ${exercise.reps}'
      else if (exercise.reps != null)
        exercise.reps!,
      if (exercise.weight != null) '${exercise.weight} kg',
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: current
            ? DesignTokens.aiVia.withOpacity(0.10)
            : DesignTokens.surface1(b),
        borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
        border: current ? Border.all(color: DesignTokens.border(b)) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: done
                  ? DesignTokens.success(b).withOpacity(0.15)
                  : DesignTokens.card(b),
              borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
            ),
            child: Icon(
              done ? LucideIcons.check : LucideIcons.dumbbell,
              size: 16,
              color: done
                  ? DesignTokens.success(b)
                  : DesignTokens.foreground(b).withOpacity(0.7),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        decoration: done ? TextDecoration.lineThrough : null,
                        color: done
                            ? DesignTokens.mutedForeground(b)
                            : DesignTokens.foreground(b),
                      ),
                ),
                if (meta.isNotEmpty)
                  Text(
                    meta,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: DesignTokens.mutedForeground(b),
                        ),
                  ),
              ],
            ),
          ),
          if (current)
            Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: DesignTokens.card(b),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'ACTUAL',
                style: DesignTokens.labelSmall(
                    fontSize: 9, color: DesignTokens.foreground(b)),
              ),
            ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => provider.toggleExerciseDone(index),
            icon: Icon(done ? LucideIcons.rotateCcw : LucideIcons.check,
                size: 16),
            tooltip: done ? 'Marcar pendiente' : 'Completar ejercicio',
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => provider.selectExercise(index),
            icon: const Icon(LucideIcons.chevronRight, size: 16),
            tooltip: 'Ir a este ejercicio',
          ),
        ],
      ),
    );
  }
}

class _ConnectionBar extends StatelessWidget {
  const _ConnectionBar({required this.provider});
  final WorkoutSessionProvider provider;

  @override
  Widget build(BuildContext context) {
    final bleState = provider.bleConnectionState;
    final isScanning = bleState == BleConnectionState.scanning;
    final isReconnecting = bleState == BleConnectionState.reconnecting;
    final isConnecting = bleState == BleConnectionState.connecting;
    final isActive = isScanning || isConnecting || isReconnecting;
    final isBleConnected = bleState == BleConnectionState.connected;

    final b = Theme.of(context).brightness;
    final Color statusColor;
    final IconData statusIcon;
    if (isBleConnected) {
      statusColor = DesignTokens.success(b);
      statusIcon = LucideIcons.bluetoothConnected;
    } else if (isActive) {
      statusColor = DesignTokens.info(b);
      statusIcon = LucideIcons.bluetooth;
    } else {
      statusColor = DesignTokens.mutedForeground(b);
      statusIcon = LucideIcons.bluetoothOff;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: DesignTokens.card(b),
        borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
        border: Border.all(color: DesignTokens.border(b)),
      ),
      child: Row(
        children: [
          if (isActive)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: statusColor,
              ),
            )
          else
            Icon(statusIcon, size: 20, color: statusColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider.connectionLabel ?? 'Sin conectar',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                if (provider.sensorContact == false)
                  Text(
                    'Sin contacto con la piel',
                    style: TextStyle(
                      color: DesignTokens.warning(b),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          if (provider.connectionLabel == null)
            TextButton(
              onPressed: () => provider.connectWatch(),
              child: const Text('Conectar'),
            ),
        ],
      ),
    );
  }
}

/// Colores de la tarjeta de FC. Vive sobre un degradado oscuro fijo (no cambia
/// con el tema), así que sus tonos son siempre los de superficie oscura.
const _hrSurfaceFrom = Color(0xFF0B1220);
const _hrSurfaceTo = Color(0xFF1A2B4B);
const _hrRmssd = Color(0xFFA78BFA); // violet-400, sin token equivalente

class _HrCard extends StatelessWidget {
  const _HrCard({required this.provider});
  final WorkoutSessionProvider provider;

  @override
  Widget build(BuildContext context) {
    final band = provider.currentIntensityBand;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_hrSurfaceFrom, _hrSurfaceTo],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.heartPulse,
                color: DesignTokens.progressRed,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Frecuencia cardíaca',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withOpacity(0.7),
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Spacer(),
              if (provider.hrSource == 'ble')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: DesignTokens.darkSuccess.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'BLE',
                    style: TextStyle(
                      color: DesignTokens.darkSuccess,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              if (provider.workoutDetected)
                Text(
                  'Entreno detectado',
                  style: TextStyle(
                    color: DesignTokens.hrZoneHigh,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: band.color.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  band.label,
                  style: TextStyle(
                    color: band.color,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${provider.currentBpm}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 52,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 6),
                child: Text(
                  'BPM · ${provider.pctOfMax}% FC máx.',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              // ── Métricas R-R / HRV ──
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (provider.lastRrMs != null)
                    Text(
                      '${provider.lastRrMs!.toStringAsFixed(0)} ms',
                      style: TextStyle(
                        color: DesignTokens.focusFgCyan.withOpacity(0.9),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  if (provider.lastRrMs != null)
                    Text(
                      'R-R',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  const SizedBox(height: 4),
                  if (provider.currentRmssd != null)
                    Text(
                      '${provider.currentRmssd!.toStringAsFixed(1)}',
                      style: TextStyle(
                        color: _hrRmssd.withOpacity(0.9),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  if (provider.currentRmssd != null)
                    Text(
                      'RMSSD',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 64,
            child: CustomPaint(
              painter: _HrGraphPainter(provider.liveGraph, fcm: provider.fcm, color: band.color),
              size: Size.infinite,
            ),
          ),
          const SizedBox(height: 12),
          _IntensityScale(pct: provider.pctOfMax),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: band.color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  provider.pctOfMax >= 91
                      ? LucideIcons.alertTriangle
                      : LucideIcons.checkCircle2,
                  size: 15,
                  color: band.color,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    band.hint,
                    style: TextStyle(
                      color: band.color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
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

class _IntensityScale extends StatelessWidget {
  const _IntensityScale({required this.pct});
  final int pct;

  static const _colors = DesignTokens.effortRamp;
  static const _flexes = [15, 12, 10, 9, 9]; // proporcional a 60/72/82/91/100
  static const _labels = ['Ligero', 'Moderado', 'Intenso', 'Cerca fallo', 'Fallo'];

  @override
  Widget build(BuildContext context) {
    final clamped = pct.clamp(45, 100).toDouble();
    final posPct = (clamped - 45) / 55;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            return SizedBox(
              height: 16,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: Row(
                        children: [
                          for (var i = 0; i < _colors.length; i++)
                            Expanded(
                              flex: _flexes[i],
                              child: Container(color: _colors[i]),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: (constraints.maxWidth * posPct - 1.5)
                        .clamp(0.0, constraints.maxWidth - 3),
                    top: -2,
                    child: Container(
                      width: 3,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: const [
                          BoxShadow(color: Colors.black38, blurRadius: 3),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: _labels
              .map((l) => Text(
                    l,
                    style: const TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                      color: Colors.white54,
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
  const dashWidth = 4.0, dashSpace = 4.0;
  final total = (end - start).distance;
  if (total <= 0) return;
  final dir = (end - start) / total;
  var drawn = 0.0;
  while (drawn < total) {
    final len = (drawn + dashWidth > total) ? total - drawn : dashWidth;
    canvas.drawLine(start + dir * drawn, start + dir * (drawn + len), paint);
    drawn += dashWidth + dashSpace;
  }
}

class _HrGraphPainter extends CustomPainter {
  final List<int> data;
  final int fcm;
  final Color color;
  _HrGraphPainter(this.data, {this.fcm = 190, this.color = DesignTokens.focusFgCyan});

  @override
  void paint(Canvas canvas, Size size) {
    final minH = 50.0, maxH = 200.0;
    double y(num v) {
      final c = (v - minH) / (maxH - minH);
      return size.height - (c.clamp(0.0, 1.0) * size.height);
    }

    // Líneas de umbral punteadas a 60/72/82/91% de la FC máx. personalizada.
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.14)
      ..strokeWidth = 1;
    for (final thresholdPct in const [60, 72, 82, 91]) {
      final v = fcm * thresholdPct / 100;
      _drawDashedLine(
          canvas, Offset(0, y(v)), Offset(size.width, y(v)), gridPaint);
    }

    if (data.length < 2) return;
    double x(int i) => (i / (data.length - 1)) * size.width;

    final path = Path()..moveTo(x(0), y(data[0]));
    for (var i = 1; i < data.length; i++) {
      path.lineTo(x(i), y(data[i]));
    }
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, paint);

    final fill = Path()..moveTo(x(0), size.height);
    for (var i = 0; i < data.length; i++) {
      fill.lineTo(x(i), y(data[i]));
    }
    fill.lineTo(x(data.length - 1), size.height);
    fill.close();
    canvas.drawPath(
      fill,
      Paint()
        ..color = color.withOpacity(0.15)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _HrGraphPainter old) =>
      old.data != data || old.fcm != fcm || old.color != color;
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({required this.provider});
  final WorkoutSessionProvider provider;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final ex = provider.currentExercise!;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: DesignTokens.card(b),
        borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
        border: Border.all(color: DesignTokens.border(b)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: DesignTokens.activityGym.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
                ),
                child: Icon(
                  LucideIcons.dumbbell,
                  size: 18,
                  color: DesignTokens.activityGym,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  ex.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Meta(
                label: 'Serie',
                value: '${provider.setIndex + 1}/${ex.sets ?? 1}',
              ),
              const SizedBox(width: 16),
              if (ex.reps != null) _Meta(label: 'Reps', value: ex.reps!),
              const SizedBox(width: 16),
              if (ex.weight != null)
                _Meta(label: 'Peso', value: '${ex.weight} kg'),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: ex.sets ?? 1,
              itemBuilder: (context, i) {
                final done = i < provider.setIndex;
                final active = i == provider.setIndex;
                return Container(
                  width: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: done
                        ? DesignTokens.success(b)
                        : active
                            ? DesignTokens.warning(b).withOpacity(0.18)
                            : DesignTokens.muted(b),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      color: done
                          ? Colors.white
                          : active
                              ? DesignTokens.warning(b)
                              : DesignTokens.mutedForeground(b),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 8),
            ),
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: DesignTokens.mutedForeground(b),
                fontWeight: FontWeight.w600,
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _PhaseControls extends StatelessWidget {
  const _PhaseControls({required this.provider});
  final WorkoutSessionProvider provider;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    switch (provider.phase) {
      case Phase.idle:
        return _PrimaryButton(
          label: 'Empezar serie',
          icon: LucideIcons.play,
          onTap: () => provider.startSet(),
        );
      case Phase.inSet:
        return Column(
          children: [
            Text(
              '${provider.setElapsed}s',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: DesignTokens.success(b),
                  ),
            ),
            const SizedBox(height: 10),
            _PrimaryButton(
              label: 'Terminar y analizar',
              icon: LucideIcons.flag,
              // Acción que dispara el análisis por IA: color de marca.
              color: DesignTokens.aiVia,
              onTap: () => provider.endSetAndAnalyze(),
            ),
          ],
        );
      case Phase.analyzing:
        return const _LoadingPill(label: 'Analizando serie con IA...');
      case Phase.rest:
        return Column(
          children: [
            Text(
              'Descanso ${provider.restRemaining}s',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: DesignTokens.info(b),
                  ),
            ),
            const SizedBox(height: 10),
            _PrimaryButton(
              label: 'Saltar descanso',
              icon: LucideIcons.skipForward,
              color: DesignTokens.info(b),
              onTap: () => provider.skipRest(),
            ),
          ],
        );
      case Phase.finished:
        return const SizedBox.shrink();
    }
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? DesignTokens.activityGym,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
          ),
        ),
      ),
    );
  }
}

class _LoadingPill extends StatelessWidget {
  const _LoadingPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: DesignTokens.aiVia,
        borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentResults extends StatelessWidget {
  const _RecentResults({required this.provider});
  final WorkoutSessionProvider provider;

  @override
  Widget build(BuildContext context) {
    final recent = provider.results.reversed.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Series analizadas',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 10),
        ...recent.map((r) => _ResultTile(result: r)),
      ],
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.result});
  final SetResult result;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final failureColor = result.reachedFailure
        ? DesignTokens.destructive(b)
        : result.sufficientIntensity
            ? DesignTokens.success(b)
            : DesignTokens.warning(b);
    final failureLabel = result.reachedFailure
        ? 'Fallo muscular'
        : result.sufficientIntensity
            ? 'Intensidad correcta'
            : 'RIR alto';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DesignTokens.card(b),
        borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
        border: Border.all(color: DesignTokens.border(b)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${result.exerciseName} · Serie ${result.setNumber}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: failureColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  failureLabel,
                  style: TextStyle(
                    color: failureColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _StatChip(label: 'RIR', value: '${result.rirEstimated}'),
              const SizedBox(width: 8),
              _StatChip(label: 'Pico', value: '${result.maxBpm} bpm'),
              const SizedBox(width: 8),
              _StatChip(label: 'Media', value: '${result.avgBpm} bpm'),
              const SizedBox(width: 8),
              _StatChip(label: 'Dur.', value: '${result.durationSec}s'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            result.feedback,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: DesignTokens.mutedForeground(b),
                ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: DesignTokens.muted(b),
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
      ),
      child: Text(
        '$label $value',
        style: DesignTokens.bodyFont(
          fontSize: 11,
          weight: FontWeight.w600,
          color: DesignTokens.foreground(b),
        ),
      ),
    );
  }
}

class _SummaryView extends StatelessWidget {
  const _SummaryView({required this.provider});
  final WorkoutSessionProvider provider;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      children: [
        Icon(
          LucideIcons.award,
          size: 56,
          color: DesignTokens.warning(b),
        ),
        const SizedBox(height: 12),
        Text(
          '¡Sesión completada!',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            _SummaryStat(
              label: 'Series',
              value: '${provider.completedSets}',
              color: DesignTokens.success(b),
            ),
            const SizedBox(width: 12),
            _SummaryStat(
              label: 'Fallo',
              value: '${provider.failureSets}',
              color: DesignTokens.destructive(b),
            ),
            const SizedBox(width: 12),
            _SummaryStat(
              label: 'Intensa',
              value: '${provider.highIntensitySets}',
              color: DesignTokens.info(b),
            ),
          ],
        ),
        if (provider.results.isNotEmpty) ...[
          const SizedBox(height: 20),
          _ComparisonCard(provider: provider),
        ],
        const SizedBox(height: 24),
        if (provider.results.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.only(top: 40),
              child: Text('No se registraron series en esta sesión.'),
            ),
          )
        else
          ...provider.results.map((r) => _ResultTile(result: r)),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.of(context)
                .pushReplacement(MaterialPageRoute(
              builder: (_) => const RoutinesHomePage(),
            )),
            icon: Icon(LucideIcons.arrowLeft),
            label: const Text('Volver a rutinas'),
          ),
        ),
      ],
    );
  }
}

/// "Vs. tu media": compara esta sesión (ya guardada en el backend con métricas
/// reales de la banda BLE) contra la media de todas las sesiones completadas
/// del usuario. `endSession()` guarda de forma asíncrona (fire-and-forget, no
/// puede bloquear el resumen), así que este widget espera a que
/// `savedSessionId` esté disponible antes de pedir el análisis.
class _ComparisonCard extends StatefulWidget {
  const _ComparisonCard({required this.provider});
  final WorkoutSessionProvider provider;

  @override
  State<_ComparisonCard> createState() => _ComparisonCardState();
}

class _ComparisonCardState extends State<_ComparisonCard> {
  Map<String, dynamic>? _analisis;
  bool _cargando = false;
  String? _idYaPedido;

  @override
  void didUpdateWidget(_ComparisonCard old) {
    super.didUpdateWidget(old);
    _pedirSiHaceFalta();
  }

  @override
  void initState() {
    super.initState();
    _pedirSiHaceFalta();
  }

  void _pedirSiHaceFalta() {
    final id = widget.provider.savedSessionId;
    if (id == null || id == _idYaPedido || _cargando) return;
    _idYaPedido = id;
    _cargar(id);
  }

  Future<void> _cargar(String id) async {
    final userId = ApiService.getCurrentUserId();
    if (userId == null) return;
    setState(() => _cargando = true);
    try {
      final res = await ApiService.getTrainingSessionAnalysis(id, userId);
      if (!mounted) return;
      setState(() => _analisis = res);
    } catch (_) {
      // Sin análisis no pasa nada grave: el resumen sigue enseñando lo suyo.
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    if (widget.provider.isSavingSession || _cargando) {
      return const SizedBox(
        height: 40,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final analisis = _analisis;
    final sesionesAnalizadas = analisis?['sesiones_analizadas'] as int? ?? 0;
    if (analisis == null || sesionesAnalizadas <= 1) {
      // La media incluye esta misma sesión (es la única forma de que el
      // backend sepa si hay suficientes datos), así que con 1 sola sesión
      // completada la comparación sería "esto vs. esto mismo".
      return const SizedBox.shrink();
    }

    final delta =
        (analisis['delta_pct'] as Map?)?.cast<String, dynamic>() ?? {};
    final filas = <(String, String, num?)>[
      ('Duración', 'duracion_minutos', delta['duracion_minutos'] as num?),
      ('Calorías', 'calorias_kcal', delta['calorias_kcal'] as num?),
      (
        'FC media',
        'frecuencia_cardiaca_media',
        delta['frecuencia_cardiaca_media'] as num?
      ),
    ].where((f) => f.$3 != null).toList();

    if (filas.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DesignTokens.surface1(b),
        borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'VS. TU MEDIA · $sesionesAnalizadas sesiones',
            style: DesignTokens.labelSmall(
                color: DesignTokens.mutedForeground(b)),
          ),
          const SizedBox(height: 10),
          for (final fila in filas)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(fila.$1,
                        style: DesignTokens.bodyFont(
                            fontSize: 13,
                            color: DesignTokens.foreground(b))),
                  ),
                  _DeltaPill(pct: fila.$3!.toDouble()),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// +12% en verde/rojo según convenga leerlo así: para la mayoría de sesiones
/// "más que tu media" no es ni bueno ni malo por sí solo, así que se muestra
/// neutro (mismo tono que el texto) en vez de arriesgar un color equivocado.
class _DeltaPill extends StatelessWidget {
  const _DeltaPill({required this.pct});
  final double pct;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final signo = pct > 0 ? '+' : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: DesignTokens.card(b),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$signo${pct.toStringAsFixed(0)}%',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: DesignTokens.foreground(b),
        ),
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: DesignTokens.bodyFont(
                fontSize: 12,
                weight: FontWeight.w600,
                color: DesignTokens.mutedForeground(b),
              ),
            ),
          ],
        ),
      ),
    );
  }
}