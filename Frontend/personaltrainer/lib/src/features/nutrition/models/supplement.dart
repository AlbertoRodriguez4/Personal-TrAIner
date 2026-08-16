import 'package:flutter/foundation.dart';

/// Un suplemento del catálogo del usuario, con si ya se tomó hoy.
///
/// Persiste en el backend (`SupplementProvider`) — catálogo y estado de hoy
/// vienen del endpoint `/supplements/user/:userId/today`.
@immutable
class Supplement {
  const Supplement({
    required this.id,
    required this.name,
    required this.dose,
    this.taken = false,
  });

  final String id;
  final String name;
  final String dose;
  final bool taken;

  Supplement copyWith({String? name, String? dose, bool? taken}) => Supplement(
        id: id,
        name: name ?? this.name,
        dose: dose ?? this.dose,
        taken: taken ?? this.taken,
      );

  factory Supplement.fromApi(Map<String, dynamic> json) => Supplement(
        id: json['id']?.toString() ?? '',
        name: json['nombre']?.toString() ?? '',
        dose: json['dosis']?.toString() ?? '',
        taken: json['tomadoHoy'] == true,
      );
}
