import 'package:flutter/material.dart';
import '../../features/routine/models/routine.dart';
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
      final raw = await ApiService.getRoutines();
      _routines = raw.map((e) => Routine.fromJson(e)).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deleteRoutine(String id) async {
    try {
      await ApiService.deleteRoutine(id);
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
        response = await ApiService.updateRoutine(id, payload);
      } else {
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

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
