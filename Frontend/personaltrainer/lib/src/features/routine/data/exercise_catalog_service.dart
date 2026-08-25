import '../../../services/api_service.dart';
import '../models/exercise_catalog.dart';

class ExerciseCatalogService {
  /// Va por `ApiService` y no por un `http.get` propio a propósito: la guarda
  /// de autenticación de NestJS es global, así que esta ruta —aunque el
  /// catálogo sea una tabla global sin `userId`— también exige el Bearer. Con
  /// un `http.get` suelto faltaba esa cabecera y el catálogo respondía 401
  /// siempre, que en pantalla se veía como "no se pudo cargar" y parecía un
  /// problema de red.
  Future<List<ExerciseGroup>> getExerciseCatalog() async {
    final data = await ApiService.getExercisesCatalog();
    final catalog = data.map(ExerciseCatalog.fromJson).toList();
    return _groupExercises(catalog);
  }

  List<ExerciseGroup> _groupExercises(List<ExerciseCatalog> catalog) {
    final Map<String, List<ExerciseCatalog>> groupedMap = {};
    for (var exercise in catalog) {
      if (!groupedMap.containsKey(exercise.grupoMuscular)) {
        groupedMap[exercise.grupoMuscular] = [];
      }
      groupedMap[exercise.grupoMuscular]!.add(exercise);
    }

    final groups = groupedMap.entries
        .map((entry) => ExerciseGroup(category: entry.key, exercises: entry.value))
        .toList();

    // Ordenar alfabéticamente por categoría
    groups.sort((a, b) => a.category.compareTo(b.category));
    return groups;
  }
}
