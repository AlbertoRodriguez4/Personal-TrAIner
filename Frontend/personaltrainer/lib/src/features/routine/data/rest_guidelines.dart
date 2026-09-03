/// Descanso recomendado entre series, deducido del rango de repeticiones.
///
/// La sesión usaba 90 s fijos para todo y sin enseñarlos: el número aparecía
/// solo al empezar la cuenta atrás, y era el mismo para un triple de sentadilla
/// que para unas elevaciones laterales. Descansar lo mismo en los dos casos no
/// es un detalle: en fuerza corta la recuperación de fosfágenos y hunde la
/// serie siguiente; en aislamiento alarga el entrenamiento sin ganar nada.
///
/// Los tramos son los aceptados en la literatura de prescripción (ACSM
/// Guidelines for Exercise Testing and Prescription; Schoenfeld et al. sobre
/// descanso e hipertrofia), no cifras inventadas para la app:
///
///  - ≤ 5 repeticiones (fuerza máxima) → 3 min
///  - 6-12 (hipertrofia)               → 90 s
///  - ≥ 13 (resistencia muscular)      → 45 s
///
/// Se clasifica por el EXTREMO BAJO del rango, que es la serie más pesada: en
/// "6-12" manda el 6. Redondear hacia el lado que más descansa es el error
/// barato; el contrario arruina la serie siguiente.
library;

const int descansoPorDefectoSegundos = 90;

const int _descansoFuerza = 180;
const int _descansoHipertrofia = 90;
const int _descansoResistencia = 45;

/// Segundos de descanso recomendados para un texto de repeticiones tal cual lo
/// escribe el usuario o la IA: "8-12", "10", "Al fallo", "12 por lado"…
///
/// Sin número reconocible se devuelve el valor por defecto: es preferible el
/// descanso de siempre a inventar una pauta a partir de un texto que no dice
/// repeticiones ("Al fallo" no implica ningún rango concreto).
int descansoRecomendadoSegundos(String? reps) {
  final numeros = RegExp(r'\d+')
      .allMatches(reps ?? '')
      .map((m) => int.tryParse(m.group(0)!))
      .whereType<int>()
      .where((n) => n > 0)
      .toList();
  if (numeros.isEmpty) return descansoPorDefectoSegundos;

  final minimo = numeros.reduce((a, b) => a < b ? a : b);
  if (minimo <= 5) return _descansoFuerza;
  if (minimo <= 12) return _descansoHipertrofia;
  return _descansoResistencia;
}

/// "3 min", "90 s" — como se escribe al lado del ejercicio.
String descansoLegible(int segundos) {
  if (segundos % 60 == 0 && segundos >= 60) {
    final min = segundos ~/ 60;
    return '$min min';
  }
  return '$segundos s';
}
