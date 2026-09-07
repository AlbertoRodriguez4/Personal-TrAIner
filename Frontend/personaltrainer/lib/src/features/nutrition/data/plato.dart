/// Un plato en construcción: la lista de ingredientes con su ración.
///
/// El registro de comida iba de uno en uno y empezando por gramos. Dos
/// problemas, y el segundo es el que hace que la gente deje de registrar:
///
///  1. Nadie pesa la comida. Fuera de casa es imposible, y en casa se hace dos
///     días. Por eso la ración se pide SIEMPRE por referencia corporal -- palma,
///     puño, puñado, pulgar -- y los gramos son la vía secundaria, no la
///     principal. Las equivalencias son las del método de la mano (Precision
///     Nutrition) y el del plato (Harvard), que ya vivían en el backend.
///  2. Comer no es comer UN alimento: es "ensalada de garbanzos con atún,
///     tomate, lechuga y un chorro de aceite". De uno en uno eso son cinco
///     búsquedas y cinco cantidades para una sola comida.
///
/// Este modelo es Dart puro a propósito: la suma y el guardado de platos
/// repetidos se pueden probar sin red ni binding.
library;

import 'dart:convert';

/// Referencias corporales, con el texto que ve el usuario. Los identificadores
/// son los del backend (`REFERENCIAS_GRAMOS`) y no se traducen aquí: si se
/// renombra uno, tiene que romper en compilación y no en silencio.
const Map<String, String> etiquetasReferencia = {
  'palma': 'Palma',
  'puno': 'Puño',
  'punado': 'Puñado',
  'pulgar': 'Pulgar',
  'vaso': 'Vaso',
  'botella': 'Botella',
  'cuarto_plato': '¼ plato',
  'media_plato': '½ plato',
  'plato_completo': 'Plato',
};

/// Qué mide cada referencia, en una línea. Sin esto, "palma" y "puño" son dos
/// palabras sin escala para quien no conoce el método de la mano.
const Map<String, String> ayudaReferencia = {
  'palma': 'La palma de tu mano, sin dedos',
  'puno': 'Tu puño cerrado',
  'punado': 'Lo que cabe en la mano cerrada',
  'pulgar': 'De la punta a la primera falange',
  'vaso': 'Un vaso normal',
  'botella': 'Una botella pequeña',
  'cuarto_plato': 'Un cuarto del plato',
  'media_plato': 'Medio plato',
  'plato_completo': 'El plato entero',
};

class IngredientePlato {
  IngredientePlato({
    required this.nombre,
    this.referenciaUnidad,
    this.referenciaCantidad = 1,
    this.cantidadG,
  });

  final String nombre;

  /// Ración por referencia corporal. Es el camino principal.
  final String? referenciaUnidad;
  final double referenciaCantidad;

  /// Gramos, para quien sí pesa o para lo que viene con etiqueta.
  final double? cantidadG;

  bool get porGramos => cantidadG != null;

  IngredientePlato copyWith({
    String? referenciaUnidad,
    double? referenciaCantidad,
    double? cantidadG,
    bool limpiarGramos = false,
  }) =>
      IngredientePlato(
        nombre: nombre,
        referenciaUnidad: referenciaUnidad ?? this.referenciaUnidad,
        referenciaCantidad: referenciaCantidad ?? this.referenciaCantidad,
        cantidadG: limpiarGramos ? null : (cantidadG ?? this.cantidadG),
      );

  /// Cuerpo que espera el backend. Se manda gramos O referencia, nunca ambos:
  /// con los dos, `_resolver_gramos` ignora la referencia y el usuario vería
  /// una ración distinta de la que eligió.
  Map<String, dynamic> toApi() => {
        'nombreAlimento': nombre,
        if (cantidadG != null)
          'cantidadG': cantidadG
        else ...{
          'referenciaUnidad': referenciaUnidad,
          'referenciaCantidad': referenciaCantidad,
        },
      };

  Map<String, dynamic> toJson() => {
        'nombre': nombre,
        if (referenciaUnidad != null) 'referencia': referenciaUnidad,
        'cantidad': referenciaCantidad,
        if (cantidadG != null) 'gramos': cantidadG,
      };

  factory IngredientePlato.fromJson(Map<String, dynamic> j) => IngredientePlato(
        nombre: j['nombre']?.toString() ?? '',
        referenciaUnidad: j['referencia']?.toString(),
        referenciaCantidad: (j['cantidad'] as num?)?.toDouble() ?? 1,
        cantidadG: (j['gramos'] as num?)?.toDouble(),
      );
}

/// Un plato guardado para repetirlo con un toque.
///
/// Es la mitad que de verdad quita trabajo: la primera vez montas la ensalada
/// ingrediente a ingrediente, y las siguientes veinte es un botón. Se guarda en
/// el dispositivo y no en el backend a propósito -- no hace falta esquema nuevo
/// para algo que solo tiene sentido para su dueño.
class PlatoGuardado {
  const PlatoGuardado({
    required this.nombre,
    required this.ingredientes,
    this.vecesUsado = 0,
  });

  final String nombre;
  final List<IngredientePlato> ingredientes;

  /// Para ordenar: lo que más repites, arriba. Registrar la comida de siempre
  /// tiene que costar un toque, no una búsqueda.
  final int vecesUsado;

  PlatoGuardado usadoUnaVezMas() => PlatoGuardado(
        nombre: nombre,
        ingredientes: ingredientes,
        vecesUsado: vecesUsado + 1,
      );

  Map<String, dynamic> toJson() => {
        'nombre': nombre,
        'veces': vecesUsado,
        'ingredientes': ingredientes.map((i) => i.toJson()).toList(),
      };

  factory PlatoGuardado.fromJson(Map<String, dynamic> j) => PlatoGuardado(
        nombre: j['nombre']?.toString() ?? '',
        vecesUsado: (j['veces'] as num?)?.toInt() ?? 0,
        ingredientes: ((j['ingredientes'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(IngredientePlato.fromJson)
            .toList(),
      );

  static String codificar(List<PlatoGuardado> platos) =>
      jsonEncode(platos.map((p) => p.toJson()).toList());

  /// Nunca lanza: un JSON corrupto no puede dejar sin registrar la comida.
  static List<PlatoGuardado> decodificar(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final lista = jsonDecode(raw);
      if (lista is! List) return const [];
      return lista
          .whereType<Map<String, dynamic>>()
          .map(PlatoGuardado.fromJson)
          .where((p) => p.nombre.isNotEmpty && p.ingredientes.isNotEmpty)
          .toList()
        ..sort((a, b) => b.vecesUsado.compareTo(a.vecesUsado));
    } catch (_) {
      return const [];
    }
  }
}
