import 'package:flutter/foundation.dart';

import '../../features/nutrition/models/supplement.dart';
import '../../services/api_service.dart';

/// Catálogo de suplementos del usuario y su estado de tomado-hoy.
///
/// A diferencia del agua (`IntakeProvider`, local y sin backend a propósito),
/// los suplementos sí persisten en el backend: `GET/POST/PATCH/DELETE
/// /supplements` + `POST /supplements/:id/toggle`.
class SupplementProvider extends ChangeNotifier {
  List<Supplement> _supplements = const [];
  List<Supplement> get supplements => List.unmodifiable(_supplements);

  bool _loaded = false;
  bool get loaded => _loaded;

  int get supplementsTaken => _supplements.where((s) => s.taken).length;

  Future<void> load() async {
    final userId = ApiService.getCurrentUserId();
    if (userId == null) return;
    try {
      final raw = await ApiService.getSupplementsToday(userId);
      _supplements = raw.map(Supplement.fromApi).toList();
    } catch (_) {
      _supplements = const [];
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> toggleSupplement(String id) async {
    final userId = ApiService.getCurrentUserId();
    if (userId == null) return;

    final index = _supplements.indexWhere((s) => s.id == id);
    if (index == -1) return;
    final optimistic = _supplements[index].copyWith(taken: !_supplements[index].taken);
    _supplements = [
      ..._supplements.sublist(0, index),
      optimistic,
      ..._supplements.sublist(index + 1),
    ];
    notifyListeners();

    try {
      final tomado = await ApiService.toggleSupplementToday(id, userId);
      final confirmedIndex = _supplements.indexWhere((s) => s.id == id);
      if (confirmedIndex != -1 && _supplements[confirmedIndex].taken != tomado) {
        _supplements[confirmedIndex] = _supplements[confirmedIndex].copyWith(taken: tomado);
        notifyListeners();
      }
    } catch (_) {
      // Revertimos el optimista si el servidor no confirmó el cambio.
      final revertIndex = _supplements.indexWhere((s) => s.id == id);
      if (revertIndex != -1) {
        _supplements[revertIndex] =
            _supplements[revertIndex].copyWith(taken: !optimistic.taken);
        notifyListeners();
      }
    }
  }

  Future<void> addSupplement(String name, String dose) async {
    final userId = ApiService.getCurrentUserId();
    final trimmedName = name.trim();
    if (userId == null || trimmedName.isEmpty) return;

    try {
      await ApiService.createSupplement(
        userId: userId,
        nombre: trimmedName,
        dosis: dose.trim().isEmpty ? null : dose.trim(),
      );
      await load();
    } catch (_) {
      // Si falla la creación, dejamos la lista tal cual estaba.
    }
  }

  Future<void> removeSupplement(String id) async {
    final userId = ApiService.getCurrentUserId();
    if (userId == null) return;

    final previous = _supplements;
    _supplements = _supplements.where((s) => s.id != id).toList();
    notifyListeners();

    try {
      await ApiService.deleteSupplement(id, userId);
    } catch (_) {
      _supplements = previous;
      notifyListeners();
    }
  }
}
