import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Hidratación del día.
///
/// Dato de auto-registro puramente local: no viaja al backend porque no
/// alimenta a la IA ni se comparte entre dispositivos, y meterlo en el
/// `DailySummary` obligaría a un round-trip por cada vaso de agua. Se
/// reinicia cada día natural — un contador que arrastra el total de ayer no
/// sirve de nada.
///
/// Los suplementos (antes también locales aquí) viven ahora en
/// `SupplementProvider`, respaldados por el backend.
class IntakeProvider extends ChangeNotifier {
  static const _kWaterMl = 'pt_water_ml';
  static const _kDay = 'pt_intake_day';

  /// Un vaso estándar y el objetivo diario, mismos valores que el diseño.
  static const int glassMl = 250;
  static const int goalMl = 2500;

  int _waterMl = 0;
  int get waterMl => _waterMl;

  bool _loaded = false;
  bool get loaded => _loaded;

  /// Vasos completos servidos hasta ahora, tope en el objetivo.
  int get glassesFilled => (_waterMl / glassMl).floor();

  /// Total de vasos que forman el objetivo diario (10 con los valores actuales).
  int get glassesGoal => (goalMl / glassMl).round();

  double get waterProgress => (_waterMl / goalMl).clamp(0.0, 1.0);

  /// Mililitros que faltan para el objetivo; 0 si ya se alcanzó.
  int get waterRemainingMl => (goalMl - _waterMl).clamp(0, goalMl);

  static String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final storedDay = prefs.getString(_kDay);
    final isNewDay = storedDay != _today();

    if (isNewDay) {
      _waterMl = 0;
      await _persist();
    } else {
      _waterMl = prefs.getInt(_kWaterMl) ?? 0;
    }

    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kWaterMl, _waterMl);
    await prefs.setString(_kDay, _today());
  }

  // ── Agua ──────────────────────────────────────────────────────────────

  /// Permitimos pasarse del objetivo (beber de más no es un error), pero con
  /// un tope al doble para que un toque repetido no dispare el contador.
  Future<void> addWater(int ml) => _setWater(_waterMl + ml);

  Future<void> removeGlass() => _setWater(_waterMl - glassMl);

  /// Fija el nivel tocando directamente el vaso número [index] (0-based).
  /// Tocar el último vaso lleno lo vacía, que es lo que se espera al corregir
  /// un toque de más.
  Future<void> setGlasses(int index) {
    final target = (index + 1) * glassMl;
    return _setWater(_waterMl == target ? target - glassMl : target);
  }

  Future<void> _setWater(int ml) async {
    _waterMl = ml.clamp(0, goalMl * 2);
    notifyListeners();
    await _persist();
  }
}
