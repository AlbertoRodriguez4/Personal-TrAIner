import 'package:flutter_test/flutter_test.dart';
import 'package:personaltrainer/src/features/routine/data/routine_transfer.dart';
import 'package:personaltrainer/src/features/routine/models/exercise.dart';

/// El JSON lo escribe una persona, y una rampa de peso se apunta de varias
/// formas. Interpretar mal una no da error en pantalla: te enseña el peso
/// equivocado justo cuando vas a cargar la barra.
void main() {
  Exercise primerEjercicio(String json) =>
      RoutineTransfer.decode(json).routine!.days.first.exercises.first;

  String conEjercicio(String ejercicio) => '''
  {"name":"R","days":[{"day_of_week":"Lunes","exercises":[$ejercicio]}]}''';

  group('formas de escribir una rampa', () {
    test('lista explicita', () {
      final ex = primerEjercicio(conEjercicio(
          '{"name":"Sentadilla","sets":3,"weights":[60,65,70]}'));
      expect(ex.weights, [60, 65, 70]);
      expect(ex.subeEnRampa, isTrue);
    });

    test('peso escrito como "60/65/70"', () {
      final ex = primerEjercicio(
          conEjercicio('{"name":"Press","sets":3,"weight":"60/65/70"}'));
      expect(ex.weights, [60, 65, 70]);
    });

    test('peso escrito con guiones, como en papel', () {
      final ex = primerEjercicio(
          conEjercicio('{"name":"Press","sets":3,"weight":"60-65-70"}'));
      expect(ex.weights, [60, 65, 70]);
    });

    test('peso inicial + incremento por serie', () {
      final ex = primerEjercicio(conEjercicio(
          '{"name":"Remo","sets":4,"weight":40,"weight_step":2.5}'));
      expect(ex.weights, [40, 42.5, 45, 47.5]);
    });

    test('nombres en castellano', () {
      final ex = primerEjercicio(conEjercicio(
          '{"name":"Curl","sets":3,"pesos_por_serie":[10,12,14]}'));
      expect(ex.weights, [10, 12, 14]);
    });
  });

  group('cuando NO hay rampa', () {
    test('un peso suelto no se convierte en lista de uno', () {
      // Si lo hiciera, `subeEnRampa` mentiria y la sesion enseñaria una
      // progresion donde no la hay.
      final ex = primerEjercicio(
          conEjercicio('{"name":"Fondos","sets":3,"weight":20}'));
      expect(ex.weights, isNull);
      expect(ex.subeEnRampa, isFalse);
      expect(ex.weight, 20);
    });

    test('una lista de un solo peso tampoco', () {
      final ex = primerEjercicio(
          conEjercicio('{"name":"Fondos","sets":3,"weights":[20]}'));
      expect(ex.subeEnRampa, isFalse);
    });

    test('incremento sin series no inventa una rampa', () {
      final ex = primerEjercicio(
          conEjercicio('{"name":"X","weight":40,"weight_step":5}'));
      expect(ex.weights, isNull);
    });
  });

  group('peso de cada serie', () {
    final rampa = Exercise(name: 'S', sets: 3, weights: const [60, 65, 70]);

    test('devuelve el de su serie', () {
      expect(rampa.pesoDeSerie(0), 60);
      expect(rampa.pesoDeSerie(2), 70);
    });

    test('una serie de mas repite el peso mas alto', () {
      // Meter una serie extra no es volver al de calentamiento.
      expect(rampa.pesoDeSerie(5), 70);
    });

    test('sin rampa siempre el peso de referencia', () {
      final plano = Exercise(name: 'S', sets: 3, weight: 50);
      expect(plano.pesoDeSerie(0), 50);
      expect(plano.pesoDeSerie(9), 50);
    });
  });

  test('exportar e importar conserva la rampa', () {
    final ex = primerEjercicio(conEjercicio(
        '{"name":"Sentadilla","sets":3,"weights":[60,65,70]}'));
    final vuelta = primerEjercicio(conEjercicio(
        '{"name":"Sentadilla","sets":3,"weights":${ex.weights}}'));
    expect(vuelta.weights, [60, 65, 70]);
  });
}
