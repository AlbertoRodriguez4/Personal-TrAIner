import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../services/api_service.dart';
import '../models/exercise_catalog.dart';

class ExerciseCatalogService {
  Future<List<ExerciseGroup>> getExerciseCatalog() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/exercises-catalog'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final List<ExerciseCatalog> catalog = data
            .map((item) => ExerciseCatalog.fromJson(item))
            .toList();

        return _groupExercises(catalog);
      } else {
        throw Exception('Failed to load exercise catalog: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
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
