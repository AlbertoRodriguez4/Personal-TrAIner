import 'package:flutter/material.dart';

import '../../../core/theme/design_tokens.dart';

/// Qué se pinta en el mapa corporal. Las tres métricas vienen en la misma
/// respuesta del backend: cambiar de una a otra no vuelve a pedir nada.
enum MuscleMetric {
  volumen(
    'Volumen',
    'Series efectivas acumuladas en el rango, comparadas con el máximo semanal recomendado para cada músculo.',
  ),
  intensidad(
    'Intensidad',
    'Esfuerzo medio de las series: RIR cuando la sesión lo registró, y %FC máxima estimada cuando no.',
  ),
  fatiga(
    'Fatiga',
    'Carga que aún no se ha recuperado, con la vida media propia de cada músculo. Baja sola con los días.',
  );

  const MuscleMetric(this.label, this.descripcion);
  final String label;
  final String descripcion;
}

/// Estado de un músculo frente a su volumen semanal recomendado.
enum MuscleStatus { sinTrabajo, bajo, enRango, alto }

/// Carga de un grupo muscular. `volumen`, `intensidad` y `fatiga` llegan ya
/// normalizadas 0-1 desde el backend: la normalización es una decisión de
/// dominio (contra el volumen semanal recomendado, no contra el máximo del
/// propio usuario) y hacerla aquí la duplicaría con otra definición.
class MuscleLoad {
  const MuscleLoad({
    required this.id,
    required this.nombre,
    required this.series,
    required this.seriesSemana,
    required this.objetivoMin,
    required this.objetivoMax,
    required this.estado,
    required this.volumen,
    required this.intensidad,
    required this.fatiga,
    required this.horasDesde,
    required this.ejercicios,
  });

  final String id;
  final String nombre;
  final double series;
  final double seriesSemana;
  final int objetivoMin;
  final int objetivoMax;
  final MuscleStatus estado;
  final double volumen;

  /// `null` cuando ninguna serie de este músculo traía RIR ni FC. Se pinta en
  /// gris, no en frío: "no lo sé" y "lo hiciste flojo" no son lo mismo, y
  /// pintarlos igual haría creer que entrenó suave quien no lleva pulsómetro.
  final double? intensidad;
  final double fatiga;
  final int? horasDesde;
  final List<({String nombre, double series})> ejercicios;

  double? valor(MuscleMetric metrica) => switch (metrica) {
    MuscleMetric.volumen => volumen,
    MuscleMetric.intensidad => intensidad,
    MuscleMetric.fatiga => fatiga,
  };

  factory MuscleLoad.fromJson(Map<String, dynamic> json) {
    final objetivo = json['objetivo'] as Map<String, dynamic>? ?? const {};
    return MuscleLoad(
      id: json['id']?.toString() ?? '',
      nombre: json['nombre']?.toString() ?? '',
      series: _double(json['series']) ?? 0,
      seriesSemana: _double(json['series_semana']) ?? 0,
      objetivoMin: (_double(objetivo['min']) ?? 0).round(),
      objetivoMax: (_double(objetivo['max']) ?? 0).round(),
      estado: switch (json['estado']) {
        'bajo' => MuscleStatus.bajo,
        'en_rango' => MuscleStatus.enRango,
        'alto' => MuscleStatus.alto,
        _ => MuscleStatus.sinTrabajo,
      },
      volumen: _double(json['volumen']) ?? 0,
      intensidad: _double(json['intensidad']),
      fatiga: _double(json['fatiga']) ?? 0,
      horasDesde: _double(json['horas_desde'])?.round(),
      ejercicios: (json['ejercicios'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (e) => (
              nombre: e['nombre']?.toString() ?? '',
              series: _double(e['series']) ?? 0,
            ),
          )
          .toList(),
    );
  }
}

/// Respuesta completa de `GET /training-sessions/user/:id/muscle-load`.
class MuscleLoadMap {
  const MuscleLoadMap({
    required this.dias,
    required this.sesiones,
    required this.seriesTotales,
    required this.seriesEstimadas,
    required this.coberturaIntensidad,
    required this.musculos,
  });

  final int dias;
  final int sesiones;
  final double seriesTotales;

  /// Parte de `seriesTotales` que sale de convertir duración de cardio en
  /// series equivalentes. Cuando pesa, la tarjeta lo dice: no es lo mismo un
  /// mapa de 40 series contadas que uno de 40 series deducidas de correr.
  final double seriesEstimadas;

  /// Fracción del volumen que traía señal de esfuerzo. La vista de intensidad
  /// avisa cuando es baja en vez de enseñar una media de dos series como si
  /// fuera la de todas.
  final double coberturaIntensidad;

  final List<MuscleLoad> musculos;

  bool get vacio => sesiones == 0 || seriesTotales == 0;

  Map<String, MuscleLoad> get porId => {for (final m in musculos) m.id: m};

  /// Valor 0-1 por músculo para la métrica pedida, tal y como lo consume el
  /// painter. `null` = sin dato (gris), 0 = medido y en frío.
  Map<String, double?> valores(MuscleMetric metrica) => {
    for (final m in musculos) m.id: m.valor(metrica),
  };

  factory MuscleLoadMap.fromJson(Map<String, dynamic> json) => MuscleLoadMap(
    dias: (_double(json['dias']) ?? 7).round(),
    sesiones: (_double(json['sesiones']) ?? 0).round(),
    seriesTotales: _double(json['series_totales']) ?? 0,
    seriesEstimadas: _double(json['series_estimadas']) ?? 0,
    coberturaIntensidad: _double(json['cobertura_intensidad']) ?? 0,
    musculos: (json['musculos'] as List? ?? const [])
        .whereType<Map>()
        .map((m) => MuscleLoad.fromJson(Map<String, dynamic>.from(m)))
        .toList(),
  );
}

/// Carga *planificada* de un grupo muscular: lo que la rutina activa escribe,
/// no lo que se ha entrenado.
///
/// No reutiliza [MuscleLoad] a propósito. Ese modelo exige `fatiga` e
/// `intensidad`, y un plan no tiene ninguna de las dos: no hay esfuerzo que
/// medir ni recuperación que decaer en un ejercicio que todavía no se ha hecho.
/// Forzarlo con ceros haría que la pantalla no pudiera distinguir "planificado
/// y descansado" de "entrenado suave".
class RoutineMuscleLoad {
  const RoutineMuscleLoad({
    required this.id,
    required this.nombre,
    required this.seriesSemana,
    required this.objetivoMin,
    required this.objetivoMax,
    required this.estado,
    required this.volumen,
  });

  final String id;
  final String nombre;
  final double seriesSemana;
  final int objetivoMin;
  final int objetivoMax;
  final MuscleStatus estado;

  /// 0-1 contra el máximo semanal recomendado, igual que en [MuscleLoad]. Nunca
  /// es `null`: un músculo que la rutina no toca son 0 series escritas, un dato
  /// que sí se tiene, no un hueco. Por eso se pinta frío y no gris.
  final double volumen;

  factory RoutineMuscleLoad.fromJson(Map<String, dynamic> json) {
    final objetivo = json['objetivo'] as Map<String, dynamic>? ?? const {};
    return RoutineMuscleLoad(
      id: json['id']?.toString() ?? '',
      nombre: json['nombre']?.toString() ?? '',
      seriesSemana: _double(json['series_semana']) ?? 0,
      objetivoMin: (_double(objetivo['min']) ?? 0).round(),
      objetivoMax: (_double(objetivo['max']) ?? 0).round(),
      estado: switch (json['estado']) {
        'bajo' => MuscleStatus.bajo,
        'en_rango' => MuscleStatus.enRango,
        'alto' => MuscleStatus.alto,
        _ => MuscleStatus.sinTrabajo,
      },
      volumen: _double(json['volumen']) ?? 0,
    );
  }
}

/// Respuesta de `GET /api/routines/user/:id/active/muscle-load`.
class RoutineMuscleLoadMap {
  const RoutineMuscleLoadMap({
    required this.activa,
    required this.routineId,
    required this.nombre,
    required this.dias,
    required this.seriesTotales,
    required this.seriesSinDeclarar,
    required this.avisoCiclo,
    required this.sinClasificar,
    required this.musculos,
  });

  /// `false` cuando el usuario no tiene rutina activa. No es un error: la
  /// pantalla lo pinta como estado vacío con la acción de crear una.
  final bool activa;

  final String? routineId;
  final String? nombre;
  final int dias;
  final double seriesTotales;

  /// Parte de [seriesTotales] que sale de suponer 3 series a un ejercicio que
  /// no las declara. Cuando pesa, la pantalla lo dice: un plan hecho de
  /// defaults no mide la rutina.
  final double seriesSinDeclarar;

  /// Presente solo si la rutina tiene más de 7 días y su ciclo ya no es
  /// semanal, con lo que la comparación con lo hecho deja de ser exacta.
  final String? avisoCiclo;

  /// Ejercicios de la rutina que no casaron con ningún músculo. Si están todos
  /// aquí el mapa sale vacío, y eso es un hueco de `muscle_map.ts`, no algo que
  /// el usuario haya hecho mal.
  final List<String> sinClasificar;

  final List<RoutineMuscleLoad> musculos;

  /// Hay rutina y series escritas, pero ni un ejercicio cayó en un músculo.
  /// Distinto de no tener rutina, y hay que decirlo distinto: aquí el usuario
  /// ya ha hecho su parte.
  bool get nadaClasificado =>
      activa && seriesTotales > 0 && musculos.every((m) => m.seriesSemana == 0);

  Map<String, RoutineMuscleLoad> get porId => {for (final m in musculos) m.id: m};

  /// Valor 0-1 por músculo, como lo consume el painter. Sin `null` a propósito:
  /// en el plan todo músculo tiene dato, aunque sea 0.
  Map<String, double?> get valores => {for (final m in musculos) m.id: m.volumen};

  factory RoutineMuscleLoadMap.fromJson(Map<String, dynamic> json) =>
      RoutineMuscleLoadMap(
        activa: json['activa'] == true,
        routineId: json['routine_id']?.toString(),
        nombre: json['nombre']?.toString(),
        dias: (_double(json['dias']) ?? 0).round(),
        seriesTotales: _double(json['series_totales']) ?? 0,
        seriesSinDeclarar: _double(json['series_sin_declarar']) ?? 0,
        avisoCiclo: json['aviso_ciclo']?.toString(),
        sinClasificar: (json['sin_clasificar'] as List? ?? const [])
            .map((e) => e.toString())
            .toList(),
        musculos: (json['musculos'] as List? ?? const [])
            .whereType<Map>()
            .map((m) => RoutineMuscleLoad.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
      );
}

double? _double(dynamic valor) {
  if (valor == null) return null;
  if (valor is num) return valor.toDouble();
  return double.tryParse(valor.toString());
}

/// Sin decimal cuando no aporta: "12 series" se lee mejor que "12.0 series", y
/// "12.5" hace falta porque una serie puede repartirse entre dos músculos.
///
/// Vive aquí y no en cada pantalla por lo mismo que `colorCarga`: la tarjeta de
/// Entrenar y el mapa a pantalla completa tienen que escribir el mismo número
/// igual, o la misma cifra se lee distinta en dos sitios.
String seriesTexto(double valor) => valor == valor.roundToDouble()
    ? valor.round().toString()
    : valor.toStringAsFixed(1);

/// Rampa cromática del mapa: la misma azul→verde→ámbar→naranja→rojo que ya
/// usan las zonas de FC y las bandas de intensidad de la sesión en vivo. Que
/// sea la misma importa — en esta app el rojo ya significa "al límite" en dos
/// pantallas más, y estrenar aquí otra escala obligaría a releer la leyenda.
Color colorCarga(double valor) {
  final ramp = DesignTokens.effortRamp;
  final t = valor.clamp(0.0, 1.0) * (ramp.length - 1);
  final i = t.floor().clamp(0, ramp.length - 2);
  return Color.lerp(ramp[i], ramp[i + 1], t - i)!;
}
