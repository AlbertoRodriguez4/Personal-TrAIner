import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:personaltrainer/src/features/routine/data/routine_transfer.dart';
import 'package:personaltrainer/src/features/routine/models/exercise.dart';
import 'package:personaltrainer/src/features/routine/models/routine.dart';
import 'package:personaltrainer/src/features/routine/models/routine_day.dart';

/// `RoutineTransfer` es Dart puro (solo `dart:convert`), así que estos tests no
/// necesitan binding ni mocks de plataforma: se ejecutan tal cual con
/// `flutter test test/routine_transfer_test.dart`.
void main() {
  group('decode — formato propio', () {
    test('lee la rutina envuelta que produce encode', () {
      final json = RoutineTransfer.encode(
        Routine(
          id: 'no-deberia-viajar',
          name: 'Push Pull Legs',
          activityType: 'gym',
          description: 'Seis días',
          days: [
            RoutineDay(
              id: 'tampoco',
              dayOfWeek: 'Lunes',
              focus: 'Empuje',
              exercises: [
                Exercise(
                  id: 'ni-este',
                  name: 'Press banca',
                  sets: 4,
                  reps: '8-10',
                  weight: 60,
                ),
              ],
            ),
          ],
        ),
      );

      // Los ids no salen en el JSON: si volvieran a entrar, el ValidationPipe de
      // NestJS (sin whitelist) los dejaría llegar al repositorio y pisarían
      // filas de otra rutina.
      expect(json.contains('no-deberia-viajar'), isFalse);
      expect(json.contains('tampoco'), isFalse);
      expect(json.contains('ni-este'), isFalse);

      final res = RoutineTransfer.decode(json);
      expect(res.warnings, isEmpty);
      expect(res.routine.name, 'Push Pull Legs');
      expect(res.routine.activityType, 'gym');
      expect(res.routine.description, 'Seis días');
      expect(res.routine.id, isNull);
      expect(res.routine.days.single.dayOfWeek, 'Lunes');
      expect(res.routine.days.single.focus, 'Empuje');
      final ejercicio = res.routine.days.single.exercises.single;
      expect(ejercicio.id, isNull);
      expect(ejercicio.name, 'Press banca');
      expect(ejercicio.sets, 4);
      expect(ejercicio.reps, '8-10');
      expect(ejercicio.weight, 60);
    });

    test('la plantilla de ejemplo es importable', () {
      final res = RoutineTransfer.decode(RoutineTransfer.plantilla);
      expect(res.warnings, isEmpty);
      expect(res.routine.days.length, 3);
      expect(res.routine.totalExercises, 10);
    });

    test('acepta una rutina pelada, sin la envoltura formato/version', () {
      final res = RoutineTransfer.decode('''
        {
          "name": "Torso pierna",
          "activity_type": "gym",
          "days": [
            {"day_of_week": "Martes", "exercises": [{"name": "Sentadilla"}]}
          ]
        }
      ''');
      expect(res.routine.name, 'Torso pierna');
      expect(res.routine.days.single.dayOfWeek, 'Martes');
    });
  });

  group('decode — JSON escrito a mano', () {
    test('acepta las claves en español y los números como texto', () {
      final res = RoutineTransfer.decode('''
        {
          "nombre": "Mi rutina",
          "tipo": "Gimnasio",
          "descripcion": "La del gimnasio",
          "dias": [
            {
              "dia": "miercoles",
              "enfoque": "Pierna",
              "ejercicios": [
                {
                  "nombre": "Prensa",
                  "series": "4 series",
                  "repeticiones": 12,
                  "peso": "62,5 kg",
                  "notas": "Sin bloquear rodilla"
                }
              ]
            }
          ]
        }
      ''');

      expect(res.warnings, isEmpty);
      expect(res.routine.name, 'Mi rutina');
      expect(res.routine.activityType, 'gym');
      expect(res.routine.days.single.dayOfWeek, 'Miércoles');
      final ejercicio = res.routine.days.single.exercises.single;
      expect(ejercicio.sets, 4);
      expect(ejercicio.reps, '12');
      expect(ejercicio.weight, 62.5);
      expect(ejercicio.notes, 'Sin bloquear rodilla');
    });

    test('normaliza los días a los siete exactos que pinta la app', () {
      // La app cruza `day_of_week` contra su lista fija: si no queda en
      // "Lunes".."Domingo" la rutina se guarda pero el plan semanal sale vacío.
      final res = RoutineTransfer.decode(jsonEncode({
        'name': 'Variantes',
        'days': [
          {'day_of_week': 'LUNES', 'exercises': <Object>[]},
          {'day_of_week': 'mié', 'exercises': <Object>[]},
          {'day_of_week': 'friday', 'exercises': <Object>[]},
          {'day_of_week': 6, 'exercises': <Object>[]},
          {
            'day_of_week': 'domingo',
            'exercises': [
              {'name': 'Caminar'},
            ],
          },
        ],
      }));

      expect(
        res.routine.days.map((d) => d.dayOfWeek).toList(),
        ['Lunes', 'Miércoles', 'Viernes', 'Sábado', 'Domingo'],
      );
    });

    test('ordena los días por semana, no por el orden del archivo', () {
      final res = RoutineTransfer.decode(jsonEncode({
        'name': 'Desordenada',
        'days': [
          {
            'day_of_week': 'Viernes',
            'exercises': [
              {'name': 'Remo'},
            ],
          },
          {
            'day_of_week': 'Lunes',
            'exercises': [
              {'name': 'Sentadilla'},
            ],
          },
        ],
      }));

      expect(res.routine.days.map((d) => d.dayOfWeek).toList(), [
        'Lunes',
        'Viernes',
      ]);
    });

    test('funde dos bloques del mismo día en uno y avisa', () {
      // Dos filas "Lunes" no dan error en el backend, pero la app solo mira la
      // primera (`days.indexWhere`), así que la otra mitad desaparecería.
      final res = RoutineTransfer.decode(jsonEncode({
        'name': 'Duplicada',
        'activity_type': 'gym',
        'days': [
          {
            'day_of_week': 'Lunes',
            'focus': 'Empuje',
            'exercises': [
              {'name': 'Press banca'},
            ],
          },
          {
            'day_of_week': 'lun',
            'exercises': [
              {'name': 'Fondos'},
            ],
          },
        ],
      }));

      expect(res.routine.days.length, 1);
      expect(res.routine.days.single.focus, 'Empuje');
      expect(res.routine.days.single.exercises.map((e) => e.name).toList(), [
        'Press banca',
        'Fondos',
      ]);
      expect(res.warnings.single, contains('Lunes'));
    });

    test('acepta que el JSON sea solo la lista de días', () {
      final res = RoutineTransfer.decode(jsonEncode([
        {
          'dia': 'Lunes',
          'ejercicios': [
            {'nombre': 'Sentadilla'},
          ],
        },
      ]));

      expect(res.routine.name, 'Rutina importada');
      expect(res.routine.activityType, 'gym');
      expect(res.warnings.length, 2); // sin nombre y sin tipo de actividad
    });

    test('un tipo de actividad desconocido cae en gimnasio con aviso', () {
      final res = RoutineTransfer.decode(jsonEncode({
        'name': 'Rara',
        'activity_type': 'parkour',
        'days': [
          {
            'day_of_week': 'Lunes',
            'exercises': [
              {'name': 'Saltos'},
            ],
          },
        ],
      }));

      expect(res.routine.activityType, 'gym');
      expect(res.warnings.single, contains('parkour'));
    });

    test('salta los ejercicios sin nombre en vez de romper la importación', () {
      final res = RoutineTransfer.decode(jsonEncode({
        'name': 'Con huecos',
        'activity_type': 'gym',
        'days': [
          {
            'day_of_week': 'Lunes',
            'exercises': [
              {'sets': 3},
              {'name': 'Dominadas', 'sets': 3},
            ],
          },
        ],
      }));

      expect(res.routine.days.single.exercises.single.name, 'Dominadas');
      expect(res.warnings.single, contains('sin nombre'));
    });

    test('recorta los textos que no caben en la columna de Postgres', () {
      // `name` es varchar(255): sin recorte el guardado revienta con un 500.
      final res = RoutineTransfer.decode(jsonEncode({
        'name': 'A' * 400,
        'days': [
          {
            'day_of_week': 'Lunes',
            'exercises': [
              {'name': 'B' * 400},
            ],
          },
        ],
      }));

      expect(res.routine.name.length, 120);
      expect(res.routine.days.single.exercises.single.name.length, 120);
    });
  });

  group('decode — errores', () {
    test('JSON malformado', () {
      expect(
        () => RoutineTransfer.decode('{"name": "Rota",}'),
        throwsA(
          isA<RoutineFormatException>().having(
            (e) => e.message,
            'message',
            contains('no es un JSON válido'),
          ),
        ),
      );
    });

    test('sin nombre', () {
      expect(
        () => RoutineTransfer.decode('{"days": [{"day_of_week": "Lunes"}]}'),
        throwsA(
          isA<RoutineFormatException>().having(
            (e) => e.message,
            'message',
            contains('nombre'),
          ),
        ),
      );
    });

    test('sin días', () {
      expect(
        () => RoutineTransfer.decode('{"name": "Vacía", "days": []}'),
        throwsA(
          isA<RoutineFormatException>().having(
            (e) => e.message,
            'message',
            contains('días'),
          ),
        ),
      );
    });

    test('un día que no es un día de la semana', () {
      expect(
        () => RoutineTransfer.decode(
          '{"name": "X", "days": [{"day_of_week": "Día 1"}]}',
        ),
        throwsA(
          isA<RoutineFormatException>().having(
            (e) => e.message,
            'message',
            contains('día de la semana válido'),
          ),
        ),
      );
    });

    test('ningún ejercicio con nombre en toda la rutina', () {
      expect(
        () => RoutineTransfer.decode(
          '{"name": "X", "days": [{"day_of_week": "Lunes", "exercises": []}]}',
        ),
        throwsA(
          isA<RoutineFormatException>().having(
            (e) => e.message,
            'message',
            contains('ejercicios'),
          ),
        ),
      );
    });

    test('texto vacío', () {
      expect(
        () => RoutineTransfer.decode('   '),
        throwsA(isA<RoutineFormatException>()),
      );
    });
  });
}
