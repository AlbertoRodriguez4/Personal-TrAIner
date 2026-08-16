import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/routine_provider.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/ui/round_icon_button.dart';
import '../../models/exercise.dart';
import '../../models/routine.dart';
import '../../models/routine_day.dart';
import '../dialogs/exercise_dialog.dart';
import 'quick_add_page.dart';
import 'routine_builder_page.dart';

const _diasSemana = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];

/// Vista de solo lectura de la rutina activa completa, día por día — réplica
/// de `routine-view.tsx` del mockup Lovable (`trainer-mind-flow`, no
/// sincronizado aún a `lovable proyect/`). Desde cada día expandido se puede
/// editar (alta rápida) o ajustar series/reps/peso de un ejercicio ya
/// existente, sin pasar por el constructor completo. Empezar una sesión NO
/// vive aquí a propósito — esa acción queda reservada a la tarjeta de "hoy"
/// dentro de Entrenamiento (`_TodayRoutineHero` en home_page.dart).
class RoutineViewPage extends StatefulWidget {
  const RoutineViewPage({super.key});

  @override
  State<RoutineViewPage> createState() => _RoutineViewPageState();
}

class _RoutineViewPageState extends State<RoutineViewPage> {
  int? _openIndex = DateTime.now().weekday - 1;

  Future<void> _editDay(Routine routine, String dayLabel) async {
    final provider = context.read<RoutineProvider>();
    final added = await Navigator.of(context).push<List<Exercise>>(
      MaterialPageRoute(
        builder: (_) => QuickAddPage(
          dayLabel: dayLabel,
          activityType: routine.activityType,
        ),
      ),
    );
    if (added == null || added.isEmpty || !context.mounted) return;

    final saved = await provider.addExercisesToDay(routine, dayLabel, added);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved != null
              ? '${added.length} ejercicios añadidos a $dayLabel.'
              : 'No se pudieron guardar los ejercicios.',
        ),
      ),
    );
  }

  Future<void> _editExercise(
    Routine routine,
    String dayLabel,
    Exercise exercise,
    int exerciseIndex,
  ) async {
    final result = await showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      backgroundColor: DesignTokens.background(Theme.of(context).brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ExerciseBottomSheet(
        activityType: routine.activityType,
        exercise: exercise,
      ),
    );
    if (result == null || !context.mounted) return;

    final provider = context.read<RoutineProvider>();
    final saved = await provider.updateExerciseInDay(
      routine,
      dayLabel,
      exerciseIndex,
      result,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved != null
              ? 'Ejercicio actualizado.'
              : 'No se pudo guardar el cambio.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final bg = DesignTokens.background(b);
    final fg = DesignTokens.foreground(b);
    final mutedFg = DesignTokens.mutedForeground(b);

    final routines = context.watch<RoutineProvider>().routines;
    final routine = routines.isNotEmpty ? routines.first : null;
    final hoy = _diasSemana[DateTime.now().weekday - 1];

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Row(
                  children: [
                    RoundIconButton(
                      icon: LucideIcons.arrowLeft,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MI RUTINA',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.4,
                            color: mutedFg,
                          ),
                        ),
                        Text(
                          'Plan semanal',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: fg,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: routine == null
                    ? _EmptyRoutineState(
                        onCreate: () {
                          final provider = context.read<RoutineProvider>();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => RoutineBuilderPage(
                                onSave: provider.loadRoutines,
                              ),
                            ),
                          );
                        },
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _RoutineSummaryCard(routine: routine),
                            const SizedBox(height: 16),
                            for (var i = 0; i < _diasSemana.length; i++) ...[
                              _RoutineDayCard(
                                dayLabel: _diasSemana[i],
                                isToday: _diasSemana[i] == hoy,
                                day: routine.days.firstWhere(
                                  (d) => d.dayOfWeek == _diasSemana[i],
                                  orElse: () =>
                                      RoutineDay(dayOfWeek: _diasSemana[i]),
                                ),
                                expanded: _openIndex == i,
                                onToggle: () => setState(
                                  () =>
                                      _openIndex = _openIndex == i ? null : i,
                                ),
                                onEdit: () =>
                                    _editDay(routine, _diasSemana[i]),
                                onEditExercise: (exercise, index) =>
                                    _editExercise(
                                      routine,
                                      _diasSemana[i],
                                      exercise,
                                      index,
                                    ),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ],
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

class _EmptyRoutineState extends StatelessWidget {
  const _EmptyRoutineState({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Todavía no tienes una rutina',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: DesignTokens.foreground(b),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Crea tu plan semanal para verlo aquí, día por día.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: DesignTokens.mutedForeground(b),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: onCreate, child: const Text('Crear rutina')),
          ],
        ),
      ),
    );
  }
}

class _RoutineSummaryCard extends StatelessWidget {
  const _RoutineSummaryCard({required this.routine});
  final Routine routine;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final fg = DesignTokens.foreground(b);
    final mutedFg = DesignTokens.mutedForeground(b);

    final diasActivos = routine.days
        .where((d) => d.exercises.isNotEmpty)
        .length;
    final ejercicios = routine.totalExercises;
    final series = routine.days.fold<int>(
      0,
      (sum, d) =>
          sum + d.exercises.fold<int>(0, (s, e) => s + (e.sets ?? 0)),
    );
    final stats = [
      ('Días', '$diasActivos'),
      ('Ejercicios', '$ejercicios'),
      ('Series', '$series'),
    ];

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
            children: [
              Icon(LucideIcons.calendarDays, size: 14, color: mutedFg),
              const SizedBox(width: 6),
              Text(
                'RESUMEN',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.4,
                  color: mutedFg,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final (i, (label, value)) in stats.indexed) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: DesignTokens.surface1(b),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Text(
                          value,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: fg,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          label.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.6,
                            color: mutedFg,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _RoutineDayCard extends StatelessWidget {
  const _RoutineDayCard({
    required this.dayLabel,
    required this.isToday,
    required this.day,
    required this.expanded,
    required this.onToggle,
    required this.onEdit,
    required this.onEditExercise,
  });

  final String dayLabel;
  final bool isToday;
  final RoutineDay day;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final void Function(Exercise exercise, int index) onEditExercise;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final fg = DesignTokens.foreground(b);
    final mutedFg = DesignTokens.mutedForeground(b);
    final sets = day.exercises.fold<int>(0, (s, e) => s + (e.sets ?? 0));
    final focus = day.focus?.isNotEmpty == true ? day.focus! : 'Descanso';

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: DesignTokens.card(b),
        borderRadius: BorderRadius.circular(24),
        boxShadow: DesignTokens.shadowSoft(b),
        border: isToday
            ? Border.all(color: DesignTokens.aiVia.withOpacity(0.4), width: 2)
            : null,
      ),
      child: Column(
        children: [
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onToggle,
              child: Padding(
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
                      child: const Icon(
                        LucideIcons.dumbbell,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  dayLabel,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: fg,
                                  ),
                                ),
                              ),
                              if (isToday) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: DesignTokens.aiGradientSoft,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    'HOY',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: fg,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            '$focus · ${day.exercises.length} ej · $sets series',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: mutedFg),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 150),
                      child: Icon(
                        LucideIcons.chevronDown,
                        size: 18,
                        color: mutedFg,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (expanded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: DesignTokens.border(b))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Text(
                    focus.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      color: mutedFg,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (day.exercises.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        'Día de descanso — sin ejercicios asignados.',
                        style: TextStyle(fontSize: 12.5, color: mutedFg),
                      ),
                    )
                  else
                    for (final (index, ex) in day.exercises.indexed)
                      _exerciseRow(context, ex, index),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(LucideIcons.plus, size: 14),
                      label: const Text('Añadir ejercicios a este día'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _exerciseRow(BuildContext context, Exercise ex, int index) {
    final b = Theme.of(context).brightness;
    final fg = DesignTokens.foreground(b);
    final mutedFg = DesignTokens.mutedForeground(b);
    final metrics = [
      if (ex.sets != null && ex.reps != null) '${ex.sets} × ${ex.reps}',
      if (ex.weight != null) '${ex.weight} kg',
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: DesignTokens.surface1(b),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ex.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
                if (metrics.isNotEmpty)
                  Text(
                    metrics.join(' · '),
                    style: TextStyle(fontSize: 11, color: mutedFg),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(LucideIcons.pencil, size: 16),
            tooltip: 'Editar ejercicio',
            onPressed: () => onEditExercise(ex, index),
          ),
        ],
      ),
    );
  }
}
