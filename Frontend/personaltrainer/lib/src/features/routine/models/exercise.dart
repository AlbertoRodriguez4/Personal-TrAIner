class Exercise {
  final String? id;
  final String name;
  final int? sets;
  final String? reps;
  final double? weight;
  final String? duration;
  final String? notes;

  Exercise({
    this.id,
    required this.name,
    this.sets,
    this.reps,
    this.weight,
    this.duration,
    this.notes,
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
  }) {
    return Exercise(
      id: id ?? this.id,
      name: name ?? this.name,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      weight: weight ?? this.weight,
      duration: duration ?? this.duration,
      notes: notes ?? this.notes,
    );
  }
}
