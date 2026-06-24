import 'exercise.dart';

class RoutineDay {
  final String? id;
  final String dayOfWeek;
  final String? focus;
  final List<Exercise> exercises;

  RoutineDay({
    this.id,
    required this.dayOfWeek,
    this.focus,
    this.exercises = const [],
  });

  factory RoutineDay.fromJson(Map<String, dynamic> json) {
    return RoutineDay(
      id: json['id']?.toString(),
      dayOfWeek: json['day_of_week']?.toString() ?? '',
      focus: json['focus']?.toString(),
      exercises: (json['exercises'] as List<dynamic>?)
              ?.map((e) => Exercise.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'day_of_week': dayOfWeek,
      if (focus != null && focus!.isNotEmpty) 'focus': focus,
      'exercises': exercises.map((e) => e.toJson()).toList(),
    };
  }

  RoutineDay copyWith({
    String? id,
    String? dayOfWeek,
    String? focus,
    List<Exercise>? exercises,
  }) {
    return RoutineDay(
      id: id ?? this.id,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      focus: focus ?? this.focus,
      exercises: exercises ?? this.exercises,
    );
  }
}
