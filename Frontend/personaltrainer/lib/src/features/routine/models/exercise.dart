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

  /// Peso de CADA serie, para los ejercicios que se suben en rampa (60-65-70).
  ///
  /// `weight` sigue siendo el peso de referencia y basta para la mayoría. Pero
  /// con un solo número hay que elegir entre apuntar el de la primera serie --y
  /// quedarse corto las dos siguientes-- o el de la última, e ir sobrado al
  /// empezar. Nulo o vacío = el ejercicio no sube, y manda `weight`.
  final List<double>? weights;

  Exercise({
    this.id,
    required this.name,
    this.sets,
    this.reps,
    this.weight,
    this.duration,
    this.notes,
    this.restSeconds,
    this.weights,
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
      weights: (json['weights'] as List?)
          ?.map((e) => double.tryParse(e.toString()))
          .whereType<double>()
          .toList(),
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
      if (weights != null && weights!.isNotEmpty) 'weights': weights,
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
    List<double>? weights,
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
      weights: weights ?? this.weights,
    );
  }

  /// Peso que toca en la serie `indice` (0-based).
  ///
  /// Con rampa devuelve el de esa serie; pasado el final se queda en el último,
  /// que es lo que pasa de verdad cuando alguien mete una serie extra: se
  /// repite el peso más alto, no se vuelve al de calentamiento.
  double? pesoDeSerie(int indice) {
    final lista = weights;
    if (lista == null || lista.isEmpty) return weight;
    if (indice < 0) return lista.first;
    return indice < lista.length ? lista[indice] : lista.last;
  }

  /// Si el ejercicio sube de peso entre series.
  bool get subeEnRampa => (weights?.length ?? 0) > 1;
}
