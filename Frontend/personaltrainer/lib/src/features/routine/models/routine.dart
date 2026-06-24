import 'routine_day.dart';

class Routine {
  final String? id;
  final String name;
  final String activityType;
  final String? description;
  final List<RoutineDay> days;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Routine({
    this.id,
    required this.name,
    required this.activityType,
    this.description,
    this.days = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory Routine.fromJson(Map<String, dynamic> json) {
    return Routine(
      id: json['id']?.toString(),
      name: json['name']?.toString() ?? '',
      activityType: json['activity_type']?.toString() ?? '',
      description: json['description']?.toString(),
      days: (json['days'] as List<dynamic>?)
              ?.map((e) => RoutineDay.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'activity_type': activityType,
      if (description != null && description!.isNotEmpty)
        'description': description,
      'days': days.map((d) => d.toJson()).toList(),
    };
  }

  Routine copyWith({
    String? id,
    String? name,
    String? activityType,
    String? description,
    List<RoutineDay>? days,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Routine(
      id: id ?? this.id,
      name: name ?? this.name,
      activityType: activityType ?? this.activityType,
      description: description ?? this.description,
      days: days ?? this.days,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  int get totalExercises {
    return days.fold(0, (sum, day) => sum + day.exercises.length);
  }

  String get activityLabel {
    switch (activityType) {
      case 'gym':
        return 'Gimnasio';
      case 'cardio':
        return 'Cardio';
      case 'calistenia':
        return 'Calistenia';
      case 'yoga':
        return 'Yoga / Pilates';
      case 'deportes':
        return 'Deportes';
      default:
        return activityType;
    }
  }
}
