import 'package:flutter_test/flutter_test.dart';
import 'package:personaltrainer/src/features/routine/models/exercise_catalog.dart';
import 'package:personaltrainer/src/features/routine/models/exercise_filters.dart';

/// Catálogo de prueba con las dos generaciones de filas que conviven de verdad
/// en la tabla: las escritas a mano antes de la importación, con grupos gruesos
/// ("Piernas") y sin imagen, y las de `free-exercise-db`, que distinguen el
/// músculo concreto.
ExerciseCatalog _e(
  String nombre,
  String grupo, [
  String? equipo,
  String? imagen,
]) => ExerciseCatalog(
  id: nombre,
  nombre: nombre,
  grupoMuscular: grupo,
  equipamiento: equipo,
  imagenUrl: imagen,
);

final _catalogo = [
  // Generación vieja
  _e('Sentadilla', 'Piernas', 'Barra'),
  _e('Curl Bíceps con Barra', 'Bíceps', 'Barra'),
  _e('Plancha', 'Core', 'Calistenia'),
  // Generación importada
  _e('Sentadilla frontal con barra', 'Cuádriceps', 'Barra', 'http://x/1.jpg'),
  _e('Curl femoral tumbado', 'Isquiotibiales', 'Máquina', 'http://x/2.jpg'),
  _e('Elevación de gemelos de pie', 'Gemelos', 'Máquina', 'http://x/3.jpg'),
  _e('Aducción de cadera en polea', 'Aductores', 'Polea', 'http://x/4.jpg'),
  _e('Press de banca con mancuernas', 'Pecho', 'Mancuernas', 'http://x/5.jpg'),
  _e('Encogimiento de hombros', 'Trapecio', 'Barra', 'http://x/6.jpg'),
];

void main() {
  group('regiones', () {
    test('solo aparecen las regiones que tienen ejercicios', () {
      final regiones = regionesConEjercicios(_catalogo);
      expect(regiones.first, filtroTodos);
      expect(regiones, contains('Piernas'));
      expect(regiones, contains('Espalda')); // por el Trapecio
      expect(regiones, contains('Brazos'));
      // Nadie tiene Cardio en este catálogo, así que ese chip no se pinta.
      expect(regiones, isNot(contains('Cardio')));
    });

    test('un grupo grueso de la generación vieja cae en su región', () {
      expect(regionDe('Piernas'), 'Piernas');
      expect(regionDe('Cuádriceps'), 'Piernas');
      // Sin tildes ni mayúsculas, que es como puede llegar de la base de datos.
      expect(regionDe('cuadriceps'), 'Piernas');
      expect(regionDe('BÍCEPS'), 'Brazos');
    });

    test('un grupo desconocido no desaparece, va a Otros', () {
      expect(regionDe('Branquias'), regionOtros);
      final conRaro = [..._catalogo, _e('Aleteo', 'Branquias')];
      expect(regionesConEjercicios(conRaro), contains(regionOtros));
    });
  });

  group('subgrupos', () {
    test('una región con un solo grupo no ofrece segunda fila', () {
      expect(subgruposDe('Pecho', _catalogo), isEmpty);
    });

    test('Piernas se desglosa y respeta el orden declarado', () {
      final sub = subgruposDe('Piernas', _catalogo);
      expect(sub.first, filtroTodos);
      expect(
        sub.sublist(1),
        ['Piernas', 'Cuádriceps', 'Isquiotibiales', 'Gemelos', 'Aductores'],
      );
    });
  });

  group('equipamientos', () {
    test('van por frecuencia, con Peso corporal primero si existe', () {
      final equipos = equipamientosDe([
        ..._catalogo,
        _e('Flexiones', 'Pecho', 'Peso corporal'),
      ]);
      expect(equipos.first, filtroTodos);
      expect(equipos[1], 'Peso corporal');
      // Barra (4) por delante de Máquina (2) y de Polea (1).
      expect(equipos.indexOf('Barra'), lessThan(equipos.indexOf('Máquina')));
      expect(equipos.indexOf('Máquina'), lessThan(equipos.indexOf('Polea')));
    });
  });

  group('filtrado', () {
    List<String> nombres(List<ExerciseCatalog> l) =>
        l.map((e) => e.nombre).toList();

    test('sin filtros devuelve todo', () {
      expect(
        filtrarEjercicios(
          _catalogo,
          region: filtroTodos,
          subgrupo: filtroTodos,
          equipamiento: filtroTodos,
          consulta: '',
        ),
        hasLength(_catalogo.length),
      );
    });

    test('la región incluye todos sus subgrupos', () {
      final piernas = filtrarEjercicios(
        _catalogo,
        region: 'Piernas',
        subgrupo: filtroTodos,
        equipamiento: filtroTodos,
        consulta: '',
      );
      expect(nombres(piernas), hasLength(5));
      expect(nombres(piernas), contains('Sentadilla'));
      expect(nombres(piernas), contains('Elevación de gemelos de pie'));
    });

    test('el subgrupo estrecha dentro de la región', () {
      final gemelos = filtrarEjercicios(
        _catalogo,
        region: 'Piernas',
        subgrupo: 'Gemelos',
        equipamiento: filtroTodos,
        consulta: '',
      );
      expect(nombres(gemelos), ['Elevación de gemelos de pie']);
    });

    test('región y equipamiento se combinan en and', () {
      final piernasBarra = filtrarEjercicios(
        _catalogo,
        region: 'Piernas',
        subgrupo: filtroTodos,
        equipamiento: 'Barra',
        consulta: '',
      );
      expect(nombres(piernasBarra), [
        'Sentadilla',
        'Sentadilla frontal con barra',
      ]);
    });

    test('una combinación imposible devuelve vacío, no todo', () {
      expect(
        filtrarEjercicios(
          _catalogo,
          region: 'Pecho',
          subgrupo: filtroTodos,
          equipamiento: 'Polea',
          consulta: '',
        ),
        isEmpty,
      );
    });

    test('la búsqueda ignora tildes y mayúsculas', () {
      final r = filtrarEjercicios(
        _catalogo,
        region: filtroTodos,
        subgrupo: filtroTodos,
        equipamiento: filtroTodos,
        consulta: 'ELEVACION',
      );
      expect(nombres(r), ['Elevación de gemelos de pie']);
    });

    test('la búsqueda también mira grupo y equipamiento', () {
      final r = filtrarEjercicios(
        _catalogo,
        region: filtroTodos,
        subgrupo: filtroTodos,
        equipamiento: filtroTodos,
        consulta: 'mancuernas',
      );
      expect(nombres(r), ['Press de banca con mancuernas']);
    });
  });
}
