import 'package:flutter/material.dart';
import '../../features/routine/models/exercise.dart';
import '../../features/routine/models/routine.dart';
import '../../features/routine/models/routine_day.dart';
import '../../services/api_service.dart';

class RoutineProvider extends ChangeNotifier {
  bool _isLoading = false;
  List<Routine> _routines = [];
  String? _error;

  bool get isLoading => _isLoading;
  List<Routine> get routines => List.unmodifiable(_routines);
  String? get error => _error;

  Future<void> loadRoutines() async {
    _setLoading(true);
    _error = null;
    try {
      final userId = ApiService.getCurrentUserId();
      if (userId == null) {
        _error = 'Usuario no autenticado';
        _routines = [];
        return;
      }
      final raw = await ApiService.getRoutines(userId);
      _routines = raw.map((e) => Routine.fromJson(e)).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deleteRoutine(String id) async {
    try {
      await ApiService.deleteRoutine(
        id,
        userId: ApiService.getCurrentUserId() ?? '',
      );
      _routines.removeWhere((r) => r.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<Routine?> saveRoutine(Map<String, dynamic> payload, {String? id}) async {
    try {
      final Map<String, dynamic> response;
      if (id != null) {
        response = await ApiService.updateRoutine(
          id,
          payload,
          userId: ApiService.getCurrentUserId() ?? '',
        );
      } else {
        final userId = ApiService.getCurrentUserId();
        if (userId != null) {
          payload['userId'] = userId;
        }
        response = await ApiService.createRoutine(payload);
      }
      final routine = Routine.fromJson(response);
      if (id != null) {
        final index = _routines.indexWhere((r) => r.id == id);
        if (index >= 0) {
          _routines[index] = routine;
        } else {
          _routines.insert(0, routine);
        }
      } else {
        _routines.insert(0, routine);
      }
      notifyListeners();
      return routine;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Añade [exercises] al día [dayLabel] de [routine] (creándolo si ese día
  /// todavía no existía) y persiste la rutina completa. Usado tanto por el
  /// alta rápida de "hoy" en Home como por el editar-por-día de
  /// RoutineViewPage, para no repetir la misma lógica de merge en cada sitio.
  Future<Routine?> addExercisesToDay(
    Routine routine,
    String dayLabel,
    List<Exercise> exercises,
  ) {
    final dayIndex = routine.days.indexWhere((d) => d.dayOfWeek == dayLabel);
    final days = List<RoutineDay>.from(routine.days);
    if (dayIndex >= 0) {
      days[dayIndex] = days[dayIndex].copyWith(
        exercises: [...days[dayIndex].exercises, ...exercises],
      );
    } else {
      days.add(RoutineDay(dayOfWeek: dayLabel, exercises: exercises));
    }
    return saveRoutine(routine.copyWith(days: days).toJson(), id: routine.id);
  }

  /// Reemplaza el ejercicio en [exerciseIndex] del día [dayLabel] por
  /// [updatedExercise] (series/reps/peso/notas) y persiste. Null si el día o
  /// el índice ya no existen (la rutina cambió entre leerla y guardar).
  Future<Routine?> updateExerciseInDay(
    Routine routine,
    String dayLabel,
    int exerciseIndex,
    Exercise updatedExercise,
  ) {
    final dayIndex = routine.days.indexWhere((d) => d.dayOfWeek == dayLabel);
    if (dayIndex < 0) return Future.value(null);
    final exercises = List<Exercise>.from(routine.days[dayIndex].exercises);
    if (exerciseIndex < 0 || exerciseIndex >= exercises.length) {
      return Future.value(null);
    }
    exercises[exerciseIndex] = updatedExercise;
    final days = List<RoutineDay>.from(routine.days);
    days[dayIndex] = days[dayIndex].copyWith(exercises: exercises);
    return saveRoutine(routine.copyWith(days: days).toJson(), id: routine.id);
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
