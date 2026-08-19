import 'package:flutter/foundation.dart';

/// Objetivo o consumido de un día: kcal + 3 macros. Misma forma para ambos
/// lados de la comparación, tal como la devuelve
/// `GET /nutrition-logs/user/:userId/day/:date`.
@immutable
class MacroTotals {
  const MacroTotals({
    this.kcal = 0,
    this.proteinasG = 0,
    this.carbohidratosG = 0,
    this.grasasG = 0,
  });

  final double kcal;
  final double proteinasG;
  final double carbohidratosG;
  final double grasasG;

  factory MacroTotals.fromJson(Map<String, dynamic> json) => MacroTotals(
        kcal: (json['kcal'] as num?)?.toDouble() ?? 0,
        proteinasG: double.tryParse('${json['proteinas_g']}') ?? 0,
        carbohidratosG: double.tryParse('${json['carbohidratos_g']}') ?? 0,
        grasasG: double.tryParse('${json['grasas_g']}') ?? 0,
      );
}

/// Una comida registrada ese día.
@immutable
class MealEntry {
  const MealEntry({
    required this.id,
    required this.tipo,
    required this.kcal,
    this.notas,
    this.nombreAlimento,
  });

  final String id;
  final String tipo;
  final int kcal;
  final String? notas;
  final String? nombreAlimento;

  factory MealEntry.fromJson(Map<String, dynamic> json) => MealEntry(
        id: json['id']?.toString() ?? '',
        tipo: json['tipo_comida']?.toString() ?? 'otro',
        kcal: (json['calorias_consumidas'] as num?)?.toInt() ?? 0,
        notas: json['notas']?.toString(),
        nombreAlimento: json['nombre_alimento']?.toString(),
      );

  static const _labels = {
    'desayuno': 'Desayuno',
    'comida': 'Comida',
    'snack': 'Snack',
    'cena': 'Cena',
    'otro': 'Comida registrada',
  };

  String get label => _labels[tipo] ?? _labels['otro']!;

  /// Nombre del alimento si se guardó (registro manual o escaneo reciente);
  /// si no, cae al tipo de comida — los registros antiguos, de antes de que
  /// `nombre_alimento` existiera como columna, no tienen otra cosa que mostrar.
  String get displayName => (nombreAlimento?.trim().isNotEmpty ?? false) ? nombreAlimento! : label;
}

/// Detalle completo de un día del calendario nutricional: objetivo vs.
/// consumido (kcal + macros) y la lista de comidas de ese día.
@immutable
class DailyNutritionDetail {
  const DailyNutritionDetail({
    required this.objetivo,
    required this.consumido,
    required this.meals,
  });

  final MacroTotals objetivo;
  final MacroTotals consumido;
  final List<MealEntry> meals;

  factory DailyNutritionDetail.fromJson(Map<String, dynamic> json) =>
      DailyNutritionDetail(
        objetivo: MacroTotals.fromJson(
          Map<String, dynamic>.from(json['objetivo'] as Map? ?? {}),
        ),
        consumido: MacroTotals.fromJson(
          Map<String, dynamic>.from(json['consumido'] as Map? ?? {}),
        ),
        meals: (json['meals'] as List? ?? [])
            .whereType<Map>()
            .map((m) => MealEntry.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
      );

  static const empty = DailyNutritionDetail(
    objetivo: MacroTotals(),
    consumido: MacroTotals(),
    meals: [],
  );
}
