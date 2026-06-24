import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/routine_provider.dart';
import '../../models/exercise.dart';
import '../../models/routine.dart';
import '../../models/routine_day.dart';
import '../dialogs/exercise_dialog.dart';

class RoutineBuilderPage extends StatefulWidget {
  const RoutineBuilderPage({super.key, this.routine, this.onSave});

  final Routine? routine;
  final VoidCallback? onSave;

  @override
  State<RoutineBuilderPage> createState() => _RoutineBuilderPageState();
}

class _RoutineBuilderPageState extends State<RoutineBuilderPage> {
  late final TextEditingController _nameController;
  late String _activityType;
  late List<String> _selectedDays;
  late List<RoutineDay> _days;
  bool _isSaving = false;

  final List<_ActivityOption> _activities = [
    _ActivityOption(
      type: 'gym',
      label: 'Gimnasio',
      description: 'Entrenamiento con pesas y máquinas',
      icon: PhosphorIcons.barbell(),
      color: Color(0xFF059669),
    ),
    _ActivityOption(
      type: 'cardio',
      label: 'Cardio',
      description: 'Running, bicicleta, elíptica...',
      icon: PhosphorIcons.personSimpleRun(),
      color: Color(0xFF2563EB),
    ),
    _ActivityOption(
      type: 'calistenia',
      label: 'Calistenia',
      description: 'Entrenamiento con peso corporal',
      icon: PhosphorIcons.personSimple(),
      color: Color(0xFFD97706),
    ),
    _ActivityOption(
      type: 'yoga',
      label: 'Yoga / Pilates',
      description: 'Flexibilidad, equilibrio y control',
      icon: PhosphorIcons.moon(),
      color: Color(0xFF7C3AED),
    ),
    _ActivityOption(
      type: 'deportes',
      label: 'Deportes',
      description: 'Fútbol, baloncesto, paddle...',
      icon: PhosphorIcons.soccerBall(),
      color: Color(0xFFEC4899),
    ),
  ];

  final List<String> _weekDays = const [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];

  Map<String, List<String>> get _focusOptions => {
        'gym': [
          'Pecho y tríceps',
          'Espalda y bíceps',
          'Piernas y glúteos',
          'Hombros y trapecio',
          'Brazos',
          'Full body',
          'Descanso',
        ],
        'cardio': [
          'HIIT',
          'Estado estable',
          'Circuito',
          'Sprints',
          'Recuperación activa',
          'Descanso',
        ],
        'calistenia': [
          'Empuje',
          'Tracción',
          'Piernas',
          'Core',
          'Skill work',
          'Descanso',
        ],
        'yoga': [
          'Vinyasa',
          'Hatha',
          'Yin',
          'Restaurativo',
          'Power yoga',
          'Descanso',
        ],
        'deportes': [
          'Técnica',
          'Táctica',
          'Fuerza específica',
          'Resistencia',
          'Partido',
          'Descanso',
        ],
      };

  @override
  void initState() {
    super.initState();
    if (widget.routine != null) {
      _nameController = TextEditingController(text: widget.routine!.name);
      _activityType = widget.routine!.activityType;
      _selectedDays = widget.routine!.days.map((d) => d.dayOfWeek).toList();
      _days = widget.routine!.days.map((d) => d.copyWith()).toList();
    } else {
      _nameController = TextEditingController();
      _activityType = '';
      _selectedDays = [];
      _days = [];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showSnack('El nombre de la rutina es obligatorio');
      return;
    }
    if (_activityType.isEmpty) {
      _showSnack('Selecciona un tipo de actividad');
      return;
    }
    if (_selectedDays.isEmpty) {
      _showSnack('Selecciona al menos un día de entrenamiento');
      return;
    }

    setState(() => _isSaving = true);

    final orderedDays = _weekDays
        .where((d) => _selectedDays.contains(d))
        .map((d) {
      final existing = _days.firstWhere(
        (day) => day.dayOfWeek == d,
        orElse: () => RoutineDay(dayOfWeek: d),
      );
      return existing;
    }).toList();

    final payload = {
      'name': name,
      'activity_type': _activityType,
      'description': '',
      'days': orderedDays.map((d) => d.toJson()).toList(),
    };

    final provider = context.read<RoutineProvider>();
    final routine = await provider.saveRoutine(
      payload,
      id: widget.routine?.id,
    );

    if (mounted) {
      if (routine != null) {
        widget.onSave?.call();
        if (widget.routine == null) {
          // Modo creación: redirigir a edición sin perder fluidez
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => RoutineBuilderPage(
                routine: routine,
                onSave: widget.onSave,
              ),
            ),
          );
        } else {
          _showSnack('Rutina guardada correctamente');
          Navigator.of(context).pop();
        }
      } else {
        _showSnack('Error al guardar: ${provider.error}');
      }
      setState(() => _isSaving = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _toggleDay(String day) {
    setState(() {
      if (_selectedDays.contains(day)) {
        _selectedDays.remove(day);
        _days.removeWhere((d) => d.dayOfWeek == day);
      } else {
        _selectedDays.add(day);
        _days.add(RoutineDay(dayOfWeek: day));
      }
    });
  }

  void _updateDayFocus(int index, String focus) {
    setState(() {
      _days[index] = _days[index].copyWith(focus: focus);
    });
  }

  void _removeDay(String day) {
    setState(() {
      _selectedDays.remove(day);
      _days.removeWhere((d) => d.dayOfWeek == day);
    });
  }

  void _openExerciseDialog({
    required int dayIndex,
    Exercise? exercise,
    int exerciseIndex = -1,
  }) async {
    final result = await showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ExerciseBottomSheet(
        activityType: _activityType,
        exercise: exercise,
      ),
    );
    if (result != null) {
      setState(() {
        final updatedExercises = List<Exercise>.from(_days[dayIndex].exercises);
        if (exercise != null && exerciseIndex >= 0) {
          updatedExercises[exerciseIndex] = result;
        } else {
          updatedExercises.add(result);
        }
        _days[dayIndex] = _days[dayIndex].copyWith(exercises: updatedExercises);
      });
    }
  }

  void _deleteExercise(int dayIndex, int exerciseIndex) {
    setState(() {
      final updated = List<Exercise>.from(_days[dayIndex].exercises);
      updated.removeAt(exerciseIndex);
      _days[dayIndex] = _days[dayIndex].copyWith(exercises: updated);
    });
  }

  Color _activityColor(String type) {
    return _activities.firstWhere((a) => a.type == type).color;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(PhosphorIcons.arrowLeft()),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: _nameController.text.isEmpty
            ? const Text('Nueva rutina')
            : Text(_nameController.text),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: _save,
                child: Text(
                  widget.routine != null ? 'Guardar' : 'Crear rutina',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0B1220),
                        ),
                    decoration: const InputDecoration(
                      hintText: 'Nombra tu rutina. Ej: Push/Pull/Legs',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF059669)),
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 28),
                  _buildStepTitle('1. Tipo de actividad'),
                  const SizedBox(height: 12),
                  if (_activityType.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Chip(
                        label: Text(
                          _activities
                              .firstWhere((a) => a.type == _activityType)
                              .label,
                        ),
                        backgroundColor:
                            _activityColor(_activityType).withOpacity(0.1),
                        side: BorderSide(
                          color: _activityColor(_activityType).withOpacity(0.3),
                        ),
                      ),
                    ),
                  _buildActivityGrid(),
                  const SizedBox(height: 28),
                  _buildStepTitle('2. Días de entrenamiento'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _weekDays.map((day) {
                      final active = _selectedDays.contains(day);
                      return ChoiceChip(
                        label: Text(day.substring(0, 2)),
                        selected: active,
                        onSelected: (_) => _toggleDay(day),
                        selectedColor: const Color(0xFF059669),
                        labelStyle: TextStyle(
                          color: active ? Colors.white : const Color(0xFF374151),
                          fontWeight: FontWeight.w600,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: active
                                ? const Color(0xFF059669)
                                : const Color(0xFFE5E7EB),
                          ),
                        ),
                        showCheckmark: false,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 28),
                  _buildStepTitle('3. Tu plan semanal'),
                  const SizedBox(height: 12),
                  if (_selectedDays.isEmpty)
                    const Text(
                      'Selecciona al menos un día para configurar tu plan.',
                      style: TextStyle(color: Color(0xFF9CA3AF)),
                    )
                  else
                    Column(
                      children: _weekDays
                          .where((d) => _selectedDays.contains(d))
                          .map((day) {
                        final index = _days.indexWhere(
                          (d) => d.dayOfWeek == day,
                        );
                        final dayData = index >= 0
                            ? _days[index]
                            : RoutineDay(dayOfWeek: day);
                        return _DayCard(
                          day: day,
                          dayData: dayData,
                          activityType: _activityType,
                          focusOptions: _focusOptions[_activityType] ?? [],
                          onFocusChanged: (focus) => _updateDayFocus(index, focus),
                          onRemove: () => _removeDay(day),
                          onAddExercise: () => _openExerciseDialog(dayIndex: index),
                          onEditExercise: (ex, exIndex) => _openExerciseDialog(
                            dayIndex: index,
                            exercise: ex,
                            exerciseIndex: exIndex,
                          ),
                          onDeleteExercise: (exIndex) =>
                              _deleteExercise(index, exIndex),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
          if (MediaQuery.of(context).viewInsets.bottom == 0)
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xFFE5E7EB)),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: SafeArea(
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: Text(
                    widget.routine != null ? 'Guardar cambios' : 'Crear rutina',
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStepTitle(String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
    );
  }

  Widget _buildActivityGrid() {
    return GridView.count(
      crossAxisCount: 1,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 3.8,
      mainAxisSpacing: 8,
      children: _activities.map((activity) {
        final selected = _activityType == activity.type;
        return InkWell(
          onTap: () => setState(() => _activityType = activity.type),
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? activity.color : const Color(0xFFE5E7EB),
                width: selected ? 2 : 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: activity.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(activity.icon, size: 20, color: activity.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        activity.label,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        activity.description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF9CA3AF),
                            ),
                      ),
                    ],
                  ),
                ),
                AnimatedOpacity(
                  opacity: selected ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: activity.color,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      PhosphorIcons.check(),
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ActivityOption {
  final String type;
  final String label;
  final String description;
  final IconData icon;
  final Color color;

  const _ActivityOption({
    required this.type,
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
  });
}

class _DayCard extends StatelessWidget {
  final String day;
  final RoutineDay dayData;
  final String activityType;
  final List<String> focusOptions;
  final ValueChanged<String> onFocusChanged;
  final VoidCallback onRemove;
  final VoidCallback onAddExercise;
  final void Function(Exercise, int) onEditExercise;
  final void Function(int) onDeleteExercise;

  const _DayCard({
    required this.day,
    required this.dayData,
    required this.activityType,
    required this.focusOptions,
    required this.onFocusChanged,
    required this.onRemove,
    required this.onAddExercise,
    required this.onEditExercise,
    required this.onDeleteExercise,
  });

  Color get _dotColor {
    switch (activityType) {
      case 'gym':
        return const Color(0xFF059669);
      case 'cardio':
        return const Color(0xFF2563EB);
      case 'calistenia':
        return const Color(0xFFD97706);
      case 'yoga':
        return const Color(0xFF7C3AED);
      case 'deportes':
        return const Color(0xFFEC4899);
      default:
        return const Color(0xFF059669);
    }
  }

  String get _shortDay {
    return day.substring(0, 2);
  }

  bool get _isRest => dayData.focus == 'Descanso';

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _dotColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _shortDay,
                    style: TextStyle(
                      color: _dotColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: focusOptions.contains(dayData.focus)
                          ? dayData.focus
                          : null,
                      hint: const Text('Selecciona enfoque'),
                      items: [
                        ...focusOptions.map((opt) => DropdownMenuItem(
                              value: opt,
                              child: Text(opt),
                            )),
                      ],
                      onChanged: (val) {
                        if (val != null) onFocusChanged(val);
                      },
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(PhosphorIcons.dotsThreeVertical(), size: 18),
                  onPressed: () {
                    showModalBottomSheet<void>(
                      context: context,
                      builder: (_) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: Icon(PhosphorIcons.trash()),
                              title: const Text('Quitar día'),
                              onTap: () {
                                Navigator.pop(context);
                                onRemove();
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          if (_isRest)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
              child: Row(
                children: [
                  Icon(
                    PhosphorIcons.moon(),
                    size: 16,
                    color: const Color(0xFF9CA3AF),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Día de recuperación',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF9CA3AF),
                        ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: [
                if (dayData.exercises.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Column(
                      children: dayData.exercises.asMap().entries.map((entry) {
                        final ex = entry.value;
                        final idx = entry.key;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FB),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _dotColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ex.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    if (ex.sets != null ||
                                        ex.reps != null ||
                                        ex.weight != null ||
                                        ex.duration != null)
                                      Text(
                                        _formatMetrics(ex),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: const Color(0xFF6B7280),
                                            ),
                                      ),
                                    if (ex.notes != null &&
                                        ex.notes!.isNotEmpty)
                                      Text(
                                        ex.notes!,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: const Color(0xFF9CA3AF),
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(PhosphorIcons.pencilSimple(),
                                        size: 18),
                                    onPressed: () =>
                                        onEditExercise(ex, idx),
                                  ),
                                  IconButton(
                                    icon: Icon(PhosphorIcons.trash(),
                                        size: 18),
                                    onPressed: () =>
                                        onDeleteExercise(idx),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: InkWell(
                    onTap: onAddExercise,
                    borderRadius: BorderRadius.circular(12),
                    child: DottedBorder(
                      borderType: BorderType.RRect,
                      radius: const Radius.circular(12),
                      color: const Color(0xFF9CA3AF),
                      dashPattern: const [6, 4],
                      strokeWidth: 1.2,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(PhosphorIcons.plus(),
                                size: 18, color: Color(0xFF6B7280)),
                            SizedBox(width: 6),
                            Text(
                              'Añadir ejercicio',
                              style: TextStyle(
                                color: Color(0xFF6B7280),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _formatMetrics(Exercise ex) {
    final parts = <String>[];
    if (ex.sets != null) parts.add('${ex.sets} series');
    if (ex.reps != null) parts.add('${ex.reps} reps');
    if (ex.weight != null) parts.add('${ex.weight} kg');
    if (ex.duration != null && ex.duration!.isNotEmpty) {
      parts.add(ex.duration!);
    }
    return parts.join(' · ');
  }
}
