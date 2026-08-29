class ExerciseCatalog {
  final String id;
  final String nombre;
  final String grupoMuscular;
  final String? equipamiento;
  final String? descripcion;
  final String? imagenUrl;

  ExerciseCatalog({
    required this.id,
    required this.nombre,
    required this.grupoMuscular,
    this.equipamiento,
    this.descripcion,
    this.imagenUrl,
  });

  factory ExerciseCatalog.fromJson(Map<String, dynamic> json) {
    return ExerciseCatalog(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      grupoMuscular: json['grupo_muscular'] as String,
      equipamiento: json['equipamiento'] as String?,
      descripcion: json['descripcion'] as String?,
      imagenUrl: json['imagen_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'grupo_muscular': grupoMuscular,
      'equipamiento': equipamiento,
      'descripcion': descripcion,
      'imagen_url': imagenUrl,
    };
  }
}

class ExerciseGroup {
  final String category;
  final List<ExerciseCatalog> exercises;

  ExerciseGroup({
    required this.category,
    required this.exercises,
  });
}
