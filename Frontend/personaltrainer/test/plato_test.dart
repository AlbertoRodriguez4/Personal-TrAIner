import 'package:flutter_test/flutter_test.dart';
import 'package:personaltrainer/src/features/nutrition/data/plato.dart';

/// El plato guardado es lo que hace que registrar la comida de siempre cueste
/// un toque. Si su serialización se rompe, el usuario pierde sus platos sin
/// que nada avise: no hay pantalla de error, simplemente dejan de estar.
void main() {
  group('ingrediente: gramos y referencia son excluyentes', () {
    test('con referencia manda la referencia', () {
      final i = IngredientePlato(
        nombre: 'Atún al natural',
        referenciaUnidad: 'palma',
        referenciaCantidad: 2,
      );
      final api = i.toApi();
      expect(api['referenciaUnidad'], 'palma');
      expect(api['referenciaCantidad'], 2);
      expect(api.containsKey('cantidadG'), isFalse);
    });

    test('con gramos NO se manda la referencia', () {
      // Mandando los dos, el backend ignora la referencia y el usuario vería
      // una ración distinta de la que eligió.
      final i = IngredientePlato(
        nombre: 'Arroz',
        referenciaUnidad: 'puno',
        cantidadG: 180,
      );
      final api = i.toApi();
      expect(api['cantidadG'], 180);
      expect(api.containsKey('referenciaUnidad'), isFalse);
    });

    test('volver a referencias limpia los gramos', () {
      final i = IngredientePlato(nombre: 'Arroz', cantidadG: 180)
          .copyWith(limpiarGramos: true, referenciaUnidad: 'puno');
      expect(i.porGramos, isFalse);
      expect(i.toApi()['referenciaUnidad'], 'puno');
    });
  });

  group('platos guardados', () {
    final ensalada = PlatoGuardado(
      nombre: 'Ensalada de garbanzos con atún',
      vecesUsado: 3,
      ingredientes: [
        IngredientePlato(nombre: 'Garbanzos cocidos', referenciaUnidad: 'puno'),
        IngredientePlato(
            nombre: 'Atún al natural', referenciaUnidad: 'palma'),
        IngredientePlato(
            nombre: 'Aceite de oliva', referenciaUnidad: 'pulgar'),
      ],
    );

    test('sobrevive al viaje de ida y vuelta', () {
      final vuelta = PlatoGuardado.decodificar(
        PlatoGuardado.codificar([ensalada]),
      ).single;
      expect(vuelta.nombre, ensalada.nombre);
      expect(vuelta.vecesUsado, 3);
      expect(vuelta.ingredientes.length, 3);
      expect(vuelta.ingredientes.first.referenciaUnidad, 'puno');
    });

    test('se ordenan por uso: lo que más repites, arriba', () {
      final lista = PlatoGuardado.decodificar(PlatoGuardado.codificar([
        const PlatoGuardado(nombre: 'Raro', ingredientes: [], vecesUsado: 1),
        ensalada,
      ]));
      // El de lista vacía se descarta ademas por no tener ingredientes.
      expect(lista.first.nombre, ensalada.nombre);
    });

    test('un JSON corrupto no deja sin registrar la comida', () {
      expect(PlatoGuardado.decodificar('{{{no es json'), isEmpty);
      expect(PlatoGuardado.decodificar(null), isEmpty);
      expect(PlatoGuardado.decodificar(''), isEmpty);
    });

    test('se descartan los platos sin nombre o sin ingredientes', () {
      final lista = PlatoGuardado.decodificar(PlatoGuardado.codificar([
        const PlatoGuardado(nombre: '', ingredientes: []),
        ensalada,
      ]));
      expect(lista.length, 1);
    });

    test('usar un plato incrementa su contador', () {
      expect(ensalada.usadoUnaVezMas().vecesUsado, 4);
    });
  });

  test('toda referencia tiene etiqueta y ayuda', () {
    // Una referencia sin texto saldria como su id crudo ("punado") en un chip.
    for (final k in etiquetasReferencia.keys) {
      expect(ayudaReferencia[k], isNotNull, reason: 'falta ayuda para $k');
    }
  });
}
