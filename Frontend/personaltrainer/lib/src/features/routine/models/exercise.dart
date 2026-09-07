class Exercise {
  final String? id;
  final String name;
  final int? sets;
  final String? reps;
  final double? weight;
  final String? duration;
  final String? notes;

  /// Descanso entre series, en segundos, tal y como lo trae la rutina.
  ///
  /// La columna `rest_seconds` existe en el backend desde siempre y el
  /// generador de rutinas por IA la rellena, pero este modelo la ignoraba: se
  /// perdía al leer y no se enviaba al guardar, así que importar una rutina por
  /// JSON con su descanso no servía de nada. Nulo = sin pauta propia, y manda
  /// la deducida del rango de repeticiones.
  final int? restSeconds;

  Exercise({
    this.id,
    required this.name,
    this.sets,
    this.reps,
    this.weight,
    this.duration,
    this.notes,
    this.restSeconds,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id']?.toString(),
      name: json['name']?.toString() ?? '',
      sets: json['sets'] != null ? int.tryParse(json['sets'].toString()) : null,
      reps: json['reps']?.toString(),
      weight: json['weight'] != null
          ? double.tryParse(json['weight'].toString())
          : null,
      duration: json['duration']?.toString(),
      notes: json['notes']?.toString(),
      restSeconds: json['rest_seconds'] != null
          ? int.tryParse(json['rest_seconds'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      if (sets != null) 'sets': sets,
      if (reps != null) 'reps': reps,
      if (weight != null) 'weight': weight,
      if (duration != null) 'duration': duration,
      if (notes != null) 'notes': notes,
      if (restSeconds != null) 'rest_seconds': restSeconds,
    };
  }

  Exercise copyWith({
    String? id,
    String? name,
    int? sets,
    String? reps,
    double? weight,
    String? duration,
    String? notes,
    int? restSeconds,
  }) {
    return Exercise(
      id: id ?? this.id,
      name: name ?? this.name,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      weight: weight ?? this.weight,
      duration: duration ?? this.duration,
      notes: notes ?? this.notes,
      restSeconds: restSeconds ?? this.restSeconds,
    );
  }
}
