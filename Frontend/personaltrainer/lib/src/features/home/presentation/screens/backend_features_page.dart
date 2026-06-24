import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../services/api_service.dart';

class BackendFeaturesPage extends StatefulWidget {
  const BackendFeaturesPage({super.key});

  @override
  State<BackendFeaturesPage> createState() => _BackendFeaturesPageState();
}

class _BackendFeaturesPageState extends State<BackendFeaturesPage> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _trainingSessions = const [];
  List<Map<String, dynamic>> _nutritionLogs = const [];
  List<Map<String, dynamic>> _dexaScans = const [];
  List<Map<String, dynamic>> _postureEvaluations = const [];
  Map<String, dynamic>? _activeSubscription;
  Map<String, dynamic>? _todayNutritionLog;

  String? get _userId => ApiService.getCurrentUserId();

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _runAction(
    Future<void> Function() action, {
    String? successMessage,
  }) async {
    try {
      await action();
      if (!mounted) return;
      if (successMessage != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(successMessage)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadAll() async {
    final userId = _userId;
    if (userId == null || userId.isEmpty) {
      return;
    }

    setState(() => _isLoading = true);
    await _runAction(() async {
      final results = await Future.wait([
        ApiService.getTrainingSessionsByUser(userId),
        ApiService.getNutritionLogsByUser(userId),
        ApiService.getDexaScansByUser(userId),
        ApiService.getPostureEvaluationsByUser(userId),
        ApiService.getActiveSubscriptionByUser(userId),
        ApiService.getTodayNutritionLog(userId),
      ]);

      if (!mounted) return;
      setState(() {
        _trainingSessions = List<Map<String, dynamic>>.from(results[0] as List);
        _nutritionLogs = List<Map<String, dynamic>>.from(results[1] as List);
        _dexaScans = List<Map<String, dynamic>>.from(results[2] as List);
        _postureEvaluations = List<Map<String, dynamic>>.from(
          results[3] as List,
        );
        _activeSubscription = results[4] as Map<String, dynamic>?;
        _todayNutritionLog = results[5] as Map<String, dynamic>?;
      });
    });
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  String _dateOnly(dynamic value) {
    if (value == null) return '-';
    final raw = value.toString();
    if (raw.contains('T')) {
      return raw.split('T').first;
    }
    if (raw.length >= 10) {
      return raw.substring(0, 10);
    }
    return raw;
  }

  String _prettyJson(Map<String, dynamic> map) {
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  Future<void> _showJsonDetails(
    String title,
    Future<Map<String, dynamic>> loader,
  ) async {
    await _runAction(() async {
      final data = await loader;
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: SelectableText(_prettyJson(data)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    });
  }

  List<Map<String, dynamic>> _parseExercises(String input) {
    final lines = input
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    return lines.map((line) {
      final parts = line.split('|');
      return {
        'nombre': parts.isNotEmpty ? parts[0].trim() : 'Ejercicio',
        'series': parts.length > 1 ? int.tryParse(parts[1].trim()) ?? 3 : 3,
        'repeticiones': parts.length > 2
            ? int.tryParse(parts[2].trim()) ?? 10
            : 10,
      };
    }).toList();
  }

  Widget _sectionCard({
    required String title,
    required String subtitle,
    required List<Widget> actions,
    required Widget child,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                ...actions,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Future<void> _openTrainingDialog({Map<String, dynamic>? current}) async {
    final isEditing = current != null;
    final existingExercises = isEditing && current['ejercicios'] is List
        ? (current['ejercicios'] as List)
              .whereType<Map>()
              .map((exercise) {
                final data = Map<String, dynamic>.from(exercise);
                return '${data['nombre'] ?? 'ejercicio'}|${data['series'] ?? 3}|${data['repeticiones'] ?? 10}';
              })
              .join('\n')
        : '';
    final dateController = TextEditingController(
      text: isEditing
          ? current['fecha_programada']?.toString() ?? ''
          : DateTime.now().toIso8601String(),
    );
    final typeController = TextEditingController(
      text: isEditing
          ? current['tipo_entrenamiento']?.toString() ?? 'fuerza'
          : 'fuerza',
    );
    final statusController = TextEditingController(
      text: isEditing
          ? current['estado']?.toString() ?? 'pendiente'
          : 'pendiente',
    );
    final exercisesController = TextEditingController(text: existingExercises);

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Editar entrenamiento' : 'Nuevo entrenamiento'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: dateController,
                decoration: const InputDecoration(
                  labelText: 'fecha_programada (ISO)',
                ),
              ),
              TextField(
                controller: typeController,
                decoration: const InputDecoration(
                  labelText: 'tipo (fuerza/cardio/flexibilidad)',
                ),
              ),
              TextField(
                controller: statusController,
                decoration: const InputDecoration(
                  labelText: 'estado (pendiente/completado)',
                ),
              ),
              TextField(
                controller: exercisesController,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'ejercicios',
                  hintText: 'sentadilla|4|12\npress banca|4|10',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final userId = _userId;
              if (userId == null) return;
              final payload = {
                'userId': userId,
                'fecha_programada': dateController.text.trim(),
                'tipo_entrenamiento': typeController.text.trim(),
                'estado': statusController.text.trim(),
                'ejercicios': _parseExercises(exercisesController.text),
              };
              await _runAction(
                () async {
                  if (isEditing) {
                    await ApiService.updateTrainingSession(
                      current['id'].toString(),
                      payload,
                    );
                  } else {
                    await ApiService.createTrainingSession(
                      userId: userId,
                      fechaProgramada: payload['fecha_programada']!.toString(),
                      tipoEntrenamiento: payload['tipo_entrenamiento']!
                          .toString(),
                      ejercicios: List<Map<String, dynamic>>.from(
                        payload['ejercicios']! as List,
                      ),
                      estado: payload['estado']!.toString(),
                    );
                  }
                  await _loadAll();
                },
                successMessage: isEditing
                    ? 'Entrenamiento actualizado'
                    : 'Entrenamiento creado',
              );
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _openNutritionDialog({Map<String, dynamic>? current}) async {
    final isEditing = current != null;
    final dateController = TextEditingController(
      text: isEditing
          ? _dateOnly(current['fecha_registro'])
          : DateTime.now().toIso8601String().split('T').first,
    );
    final calController = TextEditingController(
      text: isEditing ? current['calorias_consumidas']?.toString() ?? '0' : '0',
    );
    final pController = TextEditingController(
      text: isEditing ? current['proteinas_g']?.toString() ?? '0' : '0',
    );
    final cController = TextEditingController(
      text: isEditing ? current['carbohidratos_g']?.toString() ?? '0' : '0',
    );
    final gController = TextEditingController(
      text: isEditing ? current['grasas_g']?.toString() ?? '0' : '0',
    );
    final notesController = TextEditingController(
      text: isEditing ? current['notas']?.toString() ?? '' : '',
    );

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isEditing
              ? 'Editar registro nutricional'
              : 'Nuevo registro nutricional',
        ),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: dateController,
                decoration: const InputDecoration(labelText: 'fecha_registro'),
              ),
              TextField(
                controller: calController,
                decoration: const InputDecoration(
                  labelText: 'calorias_consumidas',
                ),
              ),
              TextField(
                controller: pController,
                decoration: const InputDecoration(labelText: 'proteinas_g'),
              ),
              TextField(
                controller: cController,
                decoration: const InputDecoration(labelText: 'carbohidratos_g'),
              ),
              TextField(
                controller: gController,
                decoration: const InputDecoration(labelText: 'grasas_g'),
              ),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'notas'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final userId = _userId;
              if (userId == null) return;
              await _runAction(
                () async {
                  if (isEditing) {
                    await ApiService.updateNutritionLog(
                      current['id'].toString(),
                      {
                        'userId': userId,
                        'fecha_registro': dateController.text.trim(),
                        'calorias_consumidas':
                            int.tryParse(calController.text.trim()) ?? 0,
                        'proteinas_g':
                            double.tryParse(pController.text.trim()) ?? 0,
                        'carbohidratos_g':
                            double.tryParse(cController.text.trim()) ?? 0,
                        'grasas_g':
                            double.tryParse(gController.text.trim()) ?? 0,
                        'notas': notesController.text.trim(),
                      },
                    );
                  } else {
                    await ApiService.createNutritionLog(
                      userId: userId,
                      fechaRegistro: dateController.text.trim(),
                      caloriasConsumidas:
                          int.tryParse(calController.text.trim()) ?? 0,
                      proteinasG: double.tryParse(pController.text.trim()) ?? 0,
                      carbohidratosG:
                          double.tryParse(cController.text.trim()) ?? 0,
                      grasasG: double.tryParse(gController.text.trim()) ?? 0,
                      notas: notesController.text.trim(),
                    );
                  }
                  await _loadAll();
                },
                successMessage: isEditing
                    ? 'Registro actualizado'
                    : 'Registro creado',
              );
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _openDexaDialog({Map<String, dynamic>? current}) async {
    final isEditing = current != null;
    final dateController = TextEditingController(
      text: isEditing
          ? _dateOnly(current['fecha_escaneo'])
          : DateTime.now().toIso8601String().split('T').first,
    );
    final fatController = TextEditingController(
      text: isEditing ? current['porcentaje_grasa']?.toString() ?? '0' : '0',
    );
    final muscleController = TextEditingController(
      text: isEditing ? current['masa_muscular_kg']?.toString() ?? '0' : '0',
    );
    final boneController = TextEditingController(
      text: isEditing ? current['densidad_osea']?.toString() ?? '0' : '0',
    );

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Editar DEXA' : 'Nuevo DEXA'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: dateController,
                decoration: const InputDecoration(labelText: 'fecha_escaneo'),
              ),
              TextField(
                controller: fatController,
                decoration: const InputDecoration(
                  labelText: 'porcentaje_grasa',
                ),
              ),
              TextField(
                controller: muscleController,
                decoration: const InputDecoration(
                  labelText: 'masa_muscular_kg',
                ),
              ),
              TextField(
                controller: boneController,
                decoration: const InputDecoration(labelText: 'densidad_osea'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final userId = _userId;
              if (userId == null) return;
              await _runAction(
                () async {
                  if (isEditing) {
                    await ApiService.updateDexaScan(current['id'].toString(), {
                      'userId': userId,
                      'fecha_escaneo': dateController.text.trim(),
                      'porcentaje_grasa':
                          double.tryParse(fatController.text.trim()) ?? 0,
                      'masa_muscular_kg':
                          double.tryParse(muscleController.text.trim()) ?? 0,
                      'densidad_osea':
                          double.tryParse(boneController.text.trim()) ?? 0,
                    });
                  } else {
                    await ApiService.createDexaScan(
                      userId: userId,
                      fechaEscaneo: dateController.text.trim(),
                      porcentajeGrasa:
                          double.tryParse(fatController.text.trim()) ?? 0,
                      masaMuscularKg:
                          double.tryParse(muscleController.text.trim()) ?? 0,
                      densidadOsea:
                          double.tryParse(boneController.text.trim()) ?? 0,
                    );
                  }
                  await _loadAll();
                },
                successMessage: isEditing ? 'DEXA actualizado' : 'DEXA creado',
              );
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _openPostureDialog({Map<String, dynamic>? current}) async {
    final isEditing = current != null;
    final dateController = TextEditingController(
      text: isEditing
          ? current['fecha_evaluacion']?.toString() ?? ''
          : DateTime.now().toIso8601String(),
    );
    final frontalController = TextEditingController(
      text: isEditing ? current['imagen_frontal_url']?.toString() ?? '' : '',
    );
    final lateralController = TextEditingController(
      text: isEditing ? current['imagen_lateral_url']?.toString() ?? '' : '',
    );
    final scoreController = TextEditingController(
      text: isEditing ? current['puntuacion_postura']?.toString() ?? '0' : '0',
    );
    final aiController = TextEditingController(
      text: isEditing ? current['analisis_ia']?.toString() ?? '' : '',
    );

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isEditing
              ? 'Editar evaluación postural'
              : 'Nueva evaluación postural',
        ),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: dateController,
                decoration: const InputDecoration(
                  labelText: 'fecha_evaluacion',
                ),
              ),
              TextField(
                controller: frontalController,
                decoration: const InputDecoration(
                  labelText: 'imagen_frontal_url',
                ),
              ),
              TextField(
                controller: lateralController,
                decoration: const InputDecoration(
                  labelText: 'imagen_lateral_url',
                ),
              ),
              TextField(
                controller: scoreController,
                decoration: const InputDecoration(
                  labelText: 'puntuacion_postura',
                ),
              ),
              TextField(
                controller: aiController,
                decoration: const InputDecoration(labelText: 'analisis_ia'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final userId = _userId;
              if (userId == null) return;
              await _runAction(
                () async {
                  if (isEditing) {
                    await ApiService.updatePostureEvaluation(
                      current['id'].toString(),
                      {
                        'userId': userId,
                        'fecha_evaluacion': dateController.text.trim(),
                        'imagen_frontal_url': frontalController.text.trim(),
                        'imagen_lateral_url': lateralController.text.trim(),
                        'puntuacion_postura':
                            double.tryParse(scoreController.text.trim()) ?? 0,
                        'analisis_ia': aiController.text.trim(),
                      },
                    );
                  } else {
                    await ApiService.createPostureEvaluation(
                      userId: userId,
                      fechaEvaluacion: dateController.text.trim(),
                      imagenFrontalUrl: frontalController.text.trim(),
                      imagenLateralUrl: lateralController.text.trim(),
                      puntuacionPostura:
                          double.tryParse(scoreController.text.trim()) ?? 0,
                      analisisIa: aiController.text.trim(),
                    );
                  }
                  await _loadAll();
                },
                successMessage: isEditing
                    ? 'Evaluacion actualizada'
                    : 'Evaluacion creada',
              );
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _openSubscriptionDialog() async {
    final planController = TextEditingController(text: 'mensual');
    final estadoController = TextEditingController(text: 'activa');
    final startController = TextEditingController(
      text: DateTime.now().toIso8601String().split('T').first,
    );
    final endController = TextEditingController(
      text: DateTime.now()
          .add(const Duration(days: 30))
          .toIso8601String()
          .split('T')
          .first,
    );

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nueva suscripcion'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: planController,
                decoration: const InputDecoration(labelText: 'plan'),
              ),
              TextField(
                controller: estadoController,
                decoration: const InputDecoration(labelText: 'estado'),
              ),
              TextField(
                controller: startController,
                decoration: const InputDecoration(labelText: 'fecha_inicio'),
              ),
              TextField(
                controller: endController,
                decoration: const InputDecoration(labelText: 'fecha_fin'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final userId = _userId;
              if (userId == null) return;
              await _runAction(() async {
                await ApiService.createSubscription(
                  userId: userId,
                  plan: planController.text.trim(),
                  estado: estadoController.text.trim(),
                  fechaInicio: startController.text.trim(),
                  fechaFin: endController.text.trim(),
                );
                await _loadAll();
              }, successMessage: 'Suscripcion creada');
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = _userId;
    if (userId == null || userId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Funciones del backend')),
        body: const Center(
          child: Text('Necesitas iniciar sesion para usar estos modulos.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Funciones del backend'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadAll,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionCard(
              title: 'Entrenamientos',
              subtitle: '${_trainingSessions.length} sesiones',
              actions: [
                IconButton(
                  onPressed: () => _openTrainingDialog(),
                  icon: const Icon(Icons.add),
                ),
              ],
              child: _trainingSessions.isEmpty
                  ? const Text('Sin sesiones registradas.')
                  : Column(
                      children: _trainingSessions.map((session) {
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            session['tipo_entrenamiento']?.toString() ??
                                'Sin tipo',
                          ),
                          subtitle: Text(
                            '${_dateOnly(session['fecha_programada'])} - ${session['estado'] ?? ''}',
                          ),
                          onTap: () => _showJsonDetails(
                            'Sesion',
                            ApiService.getTrainingSessionById(
                              session['id'].toString(),
                            ),
                          ),
                          trailing: Wrap(
                            spacing: 4,
                            children: [
                              if ((session['estado'] ?? '') != 'completado')
                                IconButton(
                                  icon: const Icon(Icons.check_circle_outline),
                                  onPressed: () => _runAction(() async {
                                    await ApiService.markTrainingSessionAsCompleted(
                                      session['id'].toString(),
                                    );
                                    await _loadAll();
                                  }, successMessage: 'Sesion completada'),
                                ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () =>
                                    _openTrainingDialog(current: session),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _runAction(() async {
                                  await ApiService.deleteTrainingSession(
                                    session['id'].toString(),
                                  );
                                  await _loadAll();
                                }, successMessage: 'Sesion eliminada'),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
            _sectionCard(
              title: 'Nutricion',
              subtitle:
                  'Hoy: ${_todayNutritionLog?['calorias_consumidas'] ?? '-'} kcal',
              actions: [
                IconButton(
                  onPressed: () => _openNutritionDialog(),
                  icon: const Icon(Icons.add),
                ),
              ],
              child: _nutritionLogs.isEmpty
                  ? const Text('Sin registros nutricionales.')
                  : Column(
                      children: _nutritionLogs.map((log) {
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('${log['calorias_consumidas']} kcal'),
                          subtitle: Text(_dateOnly(log['fecha_registro'])),
                          onTap: () => _showJsonDetails(
                            'Nutricion',
                            ApiService.getNutritionLogById(
                              log['id'].toString(),
                            ),
                          ),
                          trailing: Wrap(
                            spacing: 4,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () =>
                                    _openNutritionDialog(current: log),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _runAction(() async {
                                  await ApiService.deleteNutritionLog(
                                    log['id'].toString(),
                                  );
                                  await _loadAll();
                                }, successMessage: 'Registro eliminado'),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
            _sectionCard(
              title: 'DEXA',
              subtitle: '${_dexaScans.length} escaneos',
              actions: [
                IconButton(
                  onPressed: () => _openDexaDialog(),
                  icon: const Icon(Icons.add),
                ),
              ],
              child: _dexaScans.isEmpty
                  ? const Text('Sin escaneos DEXA.')
                  : Column(
                      children: _dexaScans.map((scan) {
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Grasa ${scan['porcentaje_grasa']}%'),
                          subtitle: Text(_dateOnly(scan['fecha_escaneo'])),
                          onTap: () => _showJsonDetails(
                            'DEXA',
                            ApiService.getDexaScanById(scan['id'].toString()),
                          ),
                          trailing: Wrap(
                            spacing: 4,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _openDexaDialog(current: scan),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _runAction(() async {
                                  await ApiService.deleteDexaScan(
                                    scan['id'].toString(),
                                  );
                                  await _loadAll();
                                }, successMessage: 'DEXA eliminado'),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
            _sectionCard(
              title: 'Evaluacion postural',
              subtitle: '${_postureEvaluations.length} evaluaciones',
              actions: [
                IconButton(
                  onPressed: () => _openPostureDialog(),
                  icon: const Icon(Icons.add),
                ),
              ],
              child: _postureEvaluations.isEmpty
                  ? const Text('Sin evaluaciones posturales.')
                  : Column(
                      children: _postureEvaluations.map((evaluation) {
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Puntaje ${evaluation['puntuacion_postura'] ?? '-'}',
                          ),
                          subtitle: Text(
                            _dateOnly(evaluation['fecha_evaluacion']),
                          ),
                          onTap: () => _showJsonDetails(
                            'Evaluacion postural',
                            ApiService.getPostureEvaluationById(
                              evaluation['id'].toString(),
                            ),
                          ),
                          trailing: Wrap(
                            spacing: 4,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () =>
                                    _openPostureDialog(current: evaluation),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _runAction(() async {
                                  await ApiService.deletePostureEvaluation(
                                    evaluation['id'].toString(),
                                  );
                                  await _loadAll();
                                }, successMessage: 'Evaluacion eliminada'),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
            _sectionCard(
              title: 'Suscripcion',
              subtitle: _activeSubscription == null
                  ? 'Sin suscripcion activa'
                  : '${_activeSubscription!['plan']} (${_activeSubscription!['estado']})',
              actions: [
                IconButton(
                  onPressed: _openSubscriptionDialog,
                  icon: const Icon(Icons.add_card),
                ),
                if (_activeSubscription != null)
                  IconButton(
                    onPressed: () => _runAction(() async {
                      await ApiService.cancelSubscription(
                        _activeSubscription!['id'].toString(),
                      );
                      await _loadAll();
                    }, successMessage: 'Suscripcion cancelada'),
                    icon: const Icon(Icons.cancel_outlined),
                  ),
              ],
              child: _activeSubscription == null
                  ? const Text('Crea una suscripcion para este usuario.')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Inicio: ${_dateOnly(_activeSubscription!['fecha_inicio'])}',
                        ),
                        Text(
                          'Fin: ${_dateOnly(_activeSubscription!['fecha_fin'])}',
                        ),
                        Text('Estado: ${_activeSubscription!['estado']}'),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
