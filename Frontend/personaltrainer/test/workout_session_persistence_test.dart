import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:personaltrainer/src/core/providers/workout_session_provider.dart';

/// La sesión sobrevive a que Android mate la app porque se guarda un resumen
/// en disco. Si `SetResult` no volviera igual de ese viaje, el resumen final
/// del entrenamiento mostraría datos falsos sin que nada avisara: no hay
/// pantalla que enseñe "esto se corrompió", simplemente saldrían otros números.
void main() {
  const original = SetResult(
    exerciseName: 'Press banca',
    setNumber: 3,
    durationSec: 47,
    maxBpm: 168,
    avgBpm: 141,
    rirEstimated: 2,
    attackSlope: 1.75,
    plateauIndex: 0.42,
    zone: 'Umbral',
    feedback: 'Buena serie, cerca del fallo.',
    reachedFailure: false,
    sufficientIntensity: true,
  );

  pruebasDeCierreDeSesion();

  test('SetResult sobrevive al viaje de ida y vuelta por JSON', () {
    final vuelta = SetResult.fromJson(
      jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
    );

    expect(vuelta.exerciseName, original.exerciseName);
    expect(vuelta.setNumber, original.setNumber);
    expect(vuelta.durationSec, original.durationSec);
    expect(vuelta.maxBpm, original.maxBpm);
    expect(vuelta.avgBpm, original.avgBpm);
    expect(vuelta.rirEstimated, original.rirEstimated);
    expect(vuelta.attackSlope, original.attackSlope);
    expect(vuelta.plateauIndex, original.plateauIndex);
    expect(vuelta.zone, original.zone);
    expect(vuelta.feedback, original.feedback);
    expect(vuelta.reachedFailure, original.reachedFailure);
    expect(vuelta.sufficientIntensity, original.sufficientIntensity);
  });

  test('los decimales no se degradan a enteros al pasar por JSON', () {
    // attackSlope y plateauIndex salen de la curva de pulsaciones y deciden el
    // RIR estimado. Un 1.75 que vuelva como 1 cambiaría el análisis de la serie.
    final vuelta = SetResult.fromJson(
      jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
    );
    expect(vuelta.attackSlope, closeTo(1.75, 1e-9));
    expect(vuelta.plateauIndex, closeTo(0.42, 1e-9));
  });

  test('un JSON incompleto no revienta: cae a valores neutros', () {
    // El resumen puede venir de una versión anterior de la app. Preferimos una
    // serie con ceros a una excepción que impida reanudar el entrenamiento.
    final vuelta = SetResult.fromJson(const {'exerciseName': 'Sentadilla'});
    expect(vuelta.exerciseName, 'Sentadilla');
    expect(vuelta.setNumber, 0);
    expect(vuelta.attackSlope, 0);
    expect(vuelta.reachedFailure, isFalse);
  });

  test('un entero donde se espera decimal se acepta', () {
    // jsonEncode escribe 2.0 como "2.0", pero un resumen editado a mano o de
    // otra versión puede traer 2: `as num` lo cubre, `as double` reventaría.
    final vuelta = SetResult.fromJson(const {
      'exerciseName': 'Remo',
      'attackSlope': 2,
      'plateauIndex': 0,
    });
    expect(vuelta.attackSlope, 2.0);
    expect(vuelta.plateauIndex, 0.0);
  });
}

/// La sesión termina cuando están hechos TODOS los ejercicios, no al pasar del
/// último de la lista. La diferencia solo se nota si te saltas alguno, que es
/// justo cuando el fallo era invisible: el entrenamiento se cerraba con
/// ejercicios sin hacer y nada lo decía.
void pruebasDeCierreDeSesion() {
  group('siguienteEjercicioPendiente', () {
    test('avanza al siguiente cuando no hay nada saltado', () {
      expect(
        siguienteEjercicioPendiente(desde: 1, total: 4, completados: {0}),
        1,
      );
    });

    test('da la vuelta para recoger los que quedaron atrás', () {
      // Terminas el último (3) habiéndote saltado el 1: no has acabado.
      expect(
        siguienteEjercicioPendiente(desde: 4, total: 4, completados: {0, 2, 3}),
        1,
      );
    });

    test('null solo cuando están todos hechos', () {
      expect(
        siguienteEjercicioPendiente(
            desde: 4, total: 4, completados: {0, 1, 2, 3}),
        isNull,
      );
    });

    test('salta los que ya están hechos en vez de volver a ellos', () {
      expect(
        siguienteEjercicioPendiente(desde: 1, total: 5, completados: {1, 2}),
        3,
      );
    });

    test('un día sin ejercicios no tiene pendientes', () {
      expect(
        siguienteEjercicioPendiente(desde: 0, total: 0, completados: {}),
        isNull,
      );
    });

    test('con uno solo: pendiente antes, terminado después', () {
      expect(
        siguienteEjercicioPendiente(desde: 1, total: 1, completados: {}),
        0,
      );
      expect(
        siguienteEjercicioPendiente(desde: 1, total: 1, completados: {0}),
        isNull,
      );
    });
  });
}
