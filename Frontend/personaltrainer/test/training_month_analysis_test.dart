import 'package:flutter_test/flutter_test.dart';
import 'package:personaltrainer/src/features/progress/data/training_month_analysis.dart';

Map<String, dynamic> sesion({
  required String fecha,
  int minutos = 60,
  String origen = 'app',
  num? kcal,
  num? fc,
}) => {
      'fecha_programada': fecha,
      'duracion_minutos': minutos,
      'origen': origen,
      if (kcal != null) 'calorias_kcal': kcal,
      if (fc != null) 'frecuencia_cardiaca_media': fc,
    };

void main() {
  group('la app manda sobre el reloj', () {
    test('un registro de Health Connect que pisa a uno de la app se descarta', () {
      // Mismo entrenamiento contado dos veces: infla medias y calendario.
      final r = sinDuplicadosDeReloj([
        sesion(fecha: '2026-09-02T18:00:00', minutos: 60),
        sesion(fecha: '2026-09-02T18:05:00', minutos: 55, origen: 'health_connect'),
      ]);
      expect(r.length, 1);
      expect(r.single['origen'], 'app');
    });

    test('se descarta aunque el reloj arranque ANTES que la app', () {
      // Te pones la banda y luego abres la app: el solape existe igual.
      final r = sinDuplicadosDeReloj([
        sesion(fecha: '2026-09-02T18:10:00', minutos: 50),
        sesion(fecha: '2026-09-02T18:00:00', minutos: 65, origen: 'health_connect'),
      ]);
      expect(r.single['origen'], 'app');
    });

    test('un entrenamiento del reloj en otro momento SÍ se conserva', () {
      // Salir a correr por la tarde no es el gimnasio de la mañana.
      final r = sinDuplicadosDeReloj([
        sesion(fecha: '2026-09-02T09:00:00', minutos: 60),
        sesion(fecha: '2026-09-02T19:00:00', minutos: 40, origen: 'health_connect'),
      ]);
      expect(r.length, 2);
    });

    test('sin sesiones de app no se descarta nada del reloj', () {
      final r = sinDuplicadosDeReloj([
        sesion(fecha: '2026-09-02T19:00:00', origen: 'health_connect'),
        sesion(fecha: '2026-09-03T19:00:00', origen: 'health_connect'),
      ]);
      expect(r.length, 2);
    });
  });

  group('medias del mes', () {
    test('promedia solo lo del mes pedido', () {
      final r = analizarMes([
        sesion(fecha: '2026-09-02T18:00:00', minutos: 60),
        sesion(fecha: '2026-09-04T18:00:00', minutos: 40),
        sesion(fecha: '2026-08-20T18:00:00', minutos: 200), // otro mes
      ], mes: DateTime(2026, 9));
      expect(r.sesiones, 2);
      expect(r.mediaMinutos, 50);
      expect(r.minutosTotales, 100);
      expect(r.diasEntrenados, 2);
    });

    test('dos sesiones el mismo día son un solo día entrenado', () {
      final r = analizarMes([
        sesion(fecha: '2026-09-02T09:00:00', minutos: 30),
        sesion(fecha: '2026-09-02T19:00:00', minutos: 30),
      ], mes: DateTime(2026, 9));
      expect(r.sesiones, 2);
      expect(r.diasEntrenados, 1);
    });

    test('kcal y FC son null si nadie las midió, no cero', () {
      // Un 0 kcal se lee como "no quemaste nada", que es una afirmación falsa.
      final r = analizarMes([
        sesion(fecha: '2026-09-02T18:00:00'),
      ], mes: DateTime(2026, 9));
      expect(r.mediaKcal, isNull);
      expect(r.mediaFc, isNull);
    });

    test('promedia kcal y FC solo sobre las sesiones que las traen', () {
      final r = analizarMes([
        sesion(fecha: '2026-09-02T18:00:00', kcal: 300, fc: 120),
        sesion(fecha: '2026-09-04T18:00:00'), // sin datos
        sesion(fecha: '2026-09-06T18:00:00', kcal: 500, fc: 140),
      ], mes: DateTime(2026, 9));
      expect(r.mediaKcal, 400);
      expect(r.mediaFc, 130);
    });

    test('el duplicado del reloj no infla las medias', () {
      final r = analizarMes([
        sesion(fecha: '2026-09-02T18:00:00', minutos: 60),
        sesion(fecha: '2026-09-02T18:05:00', minutos: 55, origen: 'health_connect'),
      ], mes: DateTime(2026, 9));
      expect(r.sesiones, 1);
      expect(r.mediaMinutos, 60);
    });

    test('un mes vacío lo dice, no devuelve ceros sueltos', () {
      final r = analizarMes(const [], mes: DateTime(2026, 9));
      expect(r.vacio, isTrue);
      expect(r.observaciones.single, contains('Sin entrenamientos'));
    });

    test('siempre hay al menos una observación con datos', () {
      final r = analizarMes([
        sesion(fecha: '2026-09-02T18:00:00', minutos: 45),
      ], mes: DateTime(2026, 9));
      expect(r.observaciones, isNotEmpty);
      expect(r.observaciones.first, contains('1 sesión'));
    });
  });
}
