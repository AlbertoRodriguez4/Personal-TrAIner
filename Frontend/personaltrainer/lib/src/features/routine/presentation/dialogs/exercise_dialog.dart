import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../models/exercise.dart';

class ExerciseBottomSheet extends StatefulWidget {
  const ExerciseBottomSheet({
    super.key,
    required this.activityType,
    this.exercise,
  });

  final String activityType;
  final Exercise? exercise;

  @override
  State<ExerciseBottomSheet> createState() => _ExerciseBottomSheetState();
}

class _ExerciseBottomSheetState extends State<ExerciseBottomSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _setsController;
  late final TextEditingController _repsController;
  late final TextEditingController _weightController;
  late final TextEditingController _durationController;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    final ex = widget.exercise;
    _nameController = TextEditingController(text: ex?.name ?? '');
    _setsController = TextEditingController(
      text: ex?.sets?.toString() ?? '',
    );
    _repsController = TextEditingController(text: ex?.reps ?? '');
    _weightController = TextEditingController(
      text: ex?.weight?.toString() ?? '',
    );
    _durationController = TextEditingController(text: ex?.duration ?? '');
    _notesController = TextEditingController(text: ex?.notes ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _setsController.dispose();
    _repsController.dispose();
    _weightController.dispose();
    _durationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _showSetsRepsWeight {
    return widget.activityType == 'gym' || widget.activityType == 'calistenia';
  }

  bool get _showWeight {
    return widget.activityType == 'gym';
  }

  bool get _showDuration {
    return widget.activityType == 'cardio' ||
        widget.activityType == 'yoga' ||
        widget.activityType == 'deportes';
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showSnack('El nombre del ejercicio es obligatorio');
      return;
    }

    final exercise = Exercise(
      id: widget.exercise?.id,
      name: name,
      sets: int.tryParse(_setsController.text.trim()),
      reps: _repsController.text.trim().isEmpty
          ? null
          : _repsController.text.trim(),
      weight: double.tryParse(_weightController.text.trim()),
      duration: _durationController.text.trim().isEmpty
          ? null
          : _durationController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    Navigator.of(context).pop(exercise);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.exercise != null
                            ? 'Editar ejercicio'
                            : 'Nuevo ejercicio',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      icon: Icon(PhosphorIcons.x(), size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre *',
                        hintText: 'Ej: Press banca',
                      ),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 12),
                    if (_showSetsRepsWeight) ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _setsController,
                              decoration: const InputDecoration(
                                labelText: 'Series',
                                hintText: '4',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _repsController,
                              decoration: const InputDecoration(
                                labelText: 'Reps',
                                hintText: '8-12',
                              ),
                              keyboardType: TextInputType.text,
                            ),
                          ),
                        ],
                      ),
                      if (_showWeight) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: _weightController,
                          decoration: const InputDecoration(
                            labelText: 'Peso (kg)',
                            hintText: '60',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ],
                    ],
                    if (_showDuration) ...[
                      TextField(
                        controller: _durationController,
                        decoration: const InputDecoration(
                          labelText: 'Duración',
                          hintText: '30 min',
                        ),
                        keyboardType: TextInputType.text,
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notas',
                        hintText: 'Tempo, RPE, sensaciones...',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _save,
                        child: const Text('Guardar ejercicio'),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
