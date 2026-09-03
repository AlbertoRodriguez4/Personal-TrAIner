import 'package:flutter_test/flutter_test.dart';
import 'package:personaltrainer/src/features/routine/data/rest_guidelines.dart';

/// El texto de repeticiones lo escribe una persona o la IA, así que llega en
/// cualquier forma. Lo que no puede pasar es que un formato raro devuelva un
/// descanso absurdo: eso no da error en pantalla, solo una pauta mala.
void main() {
  group('clasificación por el extremo bajo del rango', () {
    test('fuerza: 5 repeticiones o menos → 3 min', () {
      expect(descansoRecomendadoSegundos('5'), 180);
      expect(descansoRecomendadoSegundos('3-5'), 180);
      expect(descansoRecomendadoSegundos('1'), 180);
    });

    test('hipertrofia: 6 a 12 → 90 s', () {
      expect(descansoRecomendadoSegundos('6'), 90);
      expect(descansoRecomendadoSegundos('8-12'), 90);
      expect(descansoRecomendadoSegundos('12'), 90);
    });

    test('resistencia: 13 o más → 45 s', () {
      expect(descansoRecomendadoSegundos('15'), 45);
      expect(descansoRecomendadoSegundos('15-20'), 45);
    });

    test('manda el extremo BAJO, que es la serie más pesada', () {
      // "6-15" cruza dos tramos. Si mandara el alto saldrían 45 s para una
      // serie de 6, que es la mitad de lo que pide.
      expect(descansoRecomendadoSegundos('6-15'), 90);
      expect(descansoRecomendadoSegundos('4-8'), 180);
    });
  });

  group('texto tal y como lo escribe la gente', () {
    test('con espacios y sufijos', () {
      expect(descansoRecomendadoSegundos('8 - 12'), 90);
      expect(descansoRecomendadoSegundos('12 por lado'), 90);
      expect(descansoRecomendadoSegundos('20 reps'), 45);
    });

    test('sin numero reconocible cae al valor por defecto', () {
      // "Al fallo" no implica ningun rango: inventar una pauta a partir de ahi
      // seria peor que usar el descanso de siempre.
      expect(descansoRecomendadoSegundos('Al fallo'), descansoPorDefectoSegundos);
      expect(descansoRecomendadoSegundos(''), descansoPorDefectoSegundos);
      expect(descansoRecomendadoSegundos(null), descansoPorDefectoSegundos);
    });

    test('un cero no cuenta como rango', () {
      // "0" no es una serie; sin otro numero, se cae al por defecto.
      expect(descansoRecomendadoSegundos('0'), descansoPorDefectoSegundos);
    });
  });

  group('formato legible', () {
    test('los minutos exactos se escriben en minutos', () {
      expect(descansoLegible(180), '3 min');
      expect(descansoLegible(60), '1 min');
    });

    test('el resto en segundos', () {
      expect(descansoLegible(90), '90 s');
      expect(descansoLegible(45), '45 s');
    });
  });
}
