import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:personaltrainer/src/features/routine/data/routine_transfer.dart';
import 'package:personaltrainer/src/features/routine/models/exercise.dart';
import 'package:personaltrainer/src/features/routine/models/routine.dart';
import 'package:personaltrainer/src/features/routine/models/routine_day.dart';

final _rutina = Routine(
  id: 'rutina-de-otro-usuario',
  name: 'Push / Pull / Legs',
  activityType: 'gym',
  description: 'Tres días',
  days: [
    RoutineDay(
      id: 'dia-1',
      dayOfWeek: 'Lunes',
      focus: 'Empuje A',
      exercises: [
        Exercise(
          id: 'ej-1',
          name: 'Press de banca con mancuernas',
          sets: 4,
          reps: '8-12',
          weight: 24,
          imagenUrl: 'http://x/press.jpg',
        ),
      ],
    ),
    RoutineDay(
      id: 'dia-2',
      dayOfWeek: 'Miércoles',
      focus: 'Tracción A',
      exercises: [Exercise(id: 'ej-2', name: 'Dominadas', sets: 4, reps: 'AMRAP')],
    ),
  ],
);

void main() {
  group('exportar', () {
    test('el sobre lleva formato y versión', () {
      final sobre = jsonDecode(exportarRutina(_rutina)) as Map<String, dynamic>;
      expect(sobre['formato'], formatoRutina);
      expect(sobre['version'], versionRutina);
      expect(sobre['rutina'], isA<Map<String, dynamic>>());
    });

    test('no viaja ningún id: la rutina importada es siempre nueva', () {
      final texto = exportarRutina(_rutina);
      expect(texto.contains('rutina-de-otro-usuario'), isFalse);
      expect(texto.contains('dia-1'), isFalse);
      expect(texto.contains('ej-1'), isFalse);
    });

    test('el nombre de archivo sugerido no arrastra tildes ni barras', () {
      final nombre = nombreArchivoRutina(
        Routine(name: 'Rutina de Álvaro / verano', activityType: 'gym'),
      );
      expect(nombre, 'rutina-rutina-de-alvaro-verano.json');
    });
  });

  group('ida y vuelta', () {
    test('conserva días, nombres de día y métricas de cada ejercicio', () {
      final vuelta = importarRutina(exportarRutina(_rutina));

      expect(vuelta.id, isNull);
      expect(vuelta.name, 'Push / Pull / Legs');
      expect(vuelta.activityType, 'gym');
      expect(vuelta.days.map((d) => d.dayOfWeek), ['Lunes', 'Miércoles']);
      expect(vuelta.days.map((d) => d.focus), ['Empuje A', 'Tracción A']);

      final press = vuelta.days.first.exercises.single;
      expect(press.id, isNull);
      expect(press.name, 'Press de banca con mancuernas');
      expect(press.sets, 4);
      expect(press.reps, '8-12');
      expect(press.weight, 24);
      // La miniatura viaja con el ejercicio: sin ella la rutina importada
      // saldría entera con el marcador gris.
      expect(press.imagenUrl, 'http://x/press.jpg');
    });
  });

  group('importar remienda lo remendable', () {
    test('los días que no son de la semana se reparten por los huecos libres', () {
      final leida = importarRutina(
        jsonEncode({
          'rutina': {
            'name': 'De la IA',
            'activity_type': 'gym',
            'days': [
              {'day_of_week': 'Día 1', 'exercises': []},
              {'day_of_week': 'Día 2', 'exercises': []},
            ],
          },
        }),
      );
      expect(leida.days.map((d) => d.dayOfWeek), ['Lunes', 'Martes']);
    });

    test('un día repetido no pisa al anterior', () {
      final leida = importarRutina(
        jsonEncode({
          'rutina': {
            'name': 'Repetida',
            'activity_type': 'gym',
            'days': [
              {'day_of_week': 'Lunes', 'exercises': []},
              {'day_of_week': 'Lunes', 'exercises': []},
            ],
          },
        }),
      );
      expect(leida.days.length, 2);
      expect(leida.days.map((d) => d.dayOfWeek).toSet().length, 2);
    });

    test('se caen los ejercicios sin nombre y la actividad rara pasa a gym', () {
      final leida = importarRutina(
        jsonEncode({
          'rutina': {
            'name': 'Rara',
            'activity_type': 'crossfit',
            'days': [
              {
                'day_of_week': 'Lunes',
                'exercises': [
                  {'name': 'Sentadilla'},
                  {'name': '  '},
                  {'sets': 3},
                ],
              },
            ],
          },
        }),
      );
      expect(leida.activityType, 'gym');
      expect(leida.days.single.exercises.map((e) => e.name), ['Sentadilla']);
    });

    test('vale el objeto de la rutina pelado, sin sobre', () {
      final leida = importarRutina(
        jsonEncode({
          'name': 'Sin sobre',
          'activity_type': 'cardio',
          'days': [
            {'day_of_week': 'Viernes', 'exercises': []},
          ],
        }),
      );
      expect(leida.name, 'Sin sobre');
      expect(leida.activityType, 'cardio');
    });
  });

  group('importar rechaza', () {
    test('texto que no es JSON', () {
      expect(
        () => importarRutina('esto no es una rutina'),
        throwsA(isA<RutinaImportadaInvalida>()),
      );
    });

    test('un archivo de otra aplicación', () {
      expect(
        () => importarRutina(jsonEncode({'formato': 'otra.cosa', 'rutina': {}})),
        throwsA(isA<RutinaImportadaInvalida>()),
      );
    });

    test('una versión más nueva que la que se sabe leer', () {
      expect(
        () => importarRutina(
          jsonEncode({
            'formato': formatoRutina,
            'version': versionRutina + 1,
            'rutina': {
              'name': 'Futura',
              'days': [
                {'day_of_week': 'Lunes', 'exercises': []},
              ],
            },
          }),
        ),
        throwsA(isA<RutinaImportadaInvalida>()),
      );
    });

    test('una rutina sin días', () {
      expect(
        () => importarRutina(jsonEncode({'name': 'Vacía', 'days': []})),
        throwsA(isA<RutinaImportadaInvalida>()),
      );
    });
  });
}
