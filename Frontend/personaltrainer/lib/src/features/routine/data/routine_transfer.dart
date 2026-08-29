import 'dart:convert';

import '../models/exercise.dart';
import '../models/routine.dart';
import '../models/routine_day.dart';

/// Error de formato al leer una rutina en JSON.
///
/// El mensaje se enseña tal cual en la pantalla de importar, así que va en
/// español y nombra el campo que falla: "no se pudo leer el JSON" a secas
/// obliga a adivinar dónde está la coma de más.
class RoutineFormatException implements Exception {
  const RoutineFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Rutina leída de un JSON junto con los avisos de lo que hubo que arreglar.
///
/// Los avisos no bloquean el guardado: son cosas que se pudieron resolver
/// solas (un tipo de actividad desconocido, un peso escrito con coma, dos
/// bloques para el mismo día) y que conviene que el usuario vea antes de
/// aceptar, no errores.
class RoutineImportResult {
  const RoutineImportResult({required this.routine, this.warnings = const []});

  final Routine routine;
  final List<String> warnings;
}

/// Importar y exportar rutinas como JSON, sin pasar por la IA.
///
/// Es la vía "a mano" para meter una rutina en la app: la que te pasó un
/// amigo, la que tenías en otra aplicación o la que quieres escribir tú. Todo
/// ocurre en el cliente — no hay endpoint nuevo, la rutina resultante se
/// guarda por el `POST /routines` de siempre.
///
/// El lector es deliberadamente tolerante porque el JSON lo puede escribir una
/// persona: acepta las claves en inglés (las que exporta la app) y sus
/// equivalentes en español, los días con o sin tilde, abreviados o en inglés,
/// y los números que vengan como texto. Lo que no perdona es lo que rompería
/// la rutina más adelante:
/// - **`day_of_week` tiene que quedar en `Lunes`..`Domingo` exactos.** La app
///   cruza ese texto contra su lista fija para pintar el plan semanal y para
///   saber qué toca hoy; cualquier otra cosa se guarda pero no se ve. Es el
///   mismo motivo por el que `RoutineService.createFromAiPayload` normaliza el
///   día en el backend.
/// - **Los `id` que vengan en el JSON se tiran.** El `ValidationPipe` de NestJS
///   va sin `whitelist`, así que un `id` colado en un ejercicio llegaría hasta
///   `exerciseRepository.create()` y pisaría una fila de otra rutina.
/// - **Los textos se recortan.** `name`, `focus` y compañía son `varchar(255)`
///   en Postgres: sin recorte, un pegado largo revienta con un 500.
class RoutineTransfer {
  RoutineTransfer._();

  /// Marca del formato propio. Sirve para que un JSON exportado se reconozca a
  /// simple vista; leerlo no la exige, para que valga cualquier JSON con la
  /// forma correcta.
  static const String formato = 'personaltrainer.rutina';
  static const int version = 1;

  /// Tope de entrada. Un pegado gigante bloquearía el hilo de UI en el parseo
  /// y no hay rutina real que se acerque.
  static const int maxCaracteres = 512 * 1024;

  static const List<String> diasSemana = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];

  /// Tipos de actividad que entiende el resto de la app (`Routine.activityLabel`,
  /// `DesignTokens.activity`). Cualquier otro se convierte a `gym` con aviso.
  static const String actividadPorDefecto = 'gym';

  static const JsonEncoder _encoder = JsonEncoder.withIndent('  ');

  /// Serializa [routine] al JSON que vuelve a leer [decode].
  ///
  /// Sin `id` ni fechas: lo exportado está pensado para reimportarse (en otra
  /// cuenta, o en la misma como copia), y un `id` ajeno solo puede hacer daño.
  static String encode(Routine routine) {
    return _encoder.convert({
      'formato': formato,
      'version': version,
      'rutina': {
        'name': routine.name,
        'activity_type': routine.activityType,
        if (routine.description != null && routine.description!.isNotEmpty)
          'description': routine.description,
        'days': [
          for (final day in routine.days)
            {
              'day_of_week': day.dayOfWeek,
              if (day.focus != null && day.focus!.isNotEmpty)
                'focus': day.focus,
              'exercises': [
                for (final ex in day.exercises)
                  {
                    'name': ex.name,
                    if (ex.sets != null) 'sets': ex.sets,
                    if (ex.reps != null && ex.reps!.isNotEmpty) 'reps': ex.reps,
                    if (ex.weight != null) 'weight': ex.weight,
                    if (ex.duration != null && ex.duration!.isNotEmpty)
                      'duration': ex.duration,
                    if (ex.notes != null && ex.notes!.isNotEmpty)
                      'notes': ex.notes,
                  },
              ],
            },
        ],
      },
    });
  }

  /// JSON de ejemplo, ya relleno, para quien no sabe qué forma tiene el archivo.
  ///
  /// Es el mejor sustituto de una documentación que nadie va a leer: se carga
  /// en el cuadro de texto y se edita encima.
  static String get plantilla => _encoder.convert({
        'formato': formato,
        'version': version,
        'rutina': {
          'name': 'Full body 3 días',
          'activity_type': 'gym',
          'description': 'Plantilla de ejemplo: cámbiala a tu gusto',
          'days': [
            {
              'day_of_week': 'Lunes',
              'focus': 'Full body',
              'exercises': [
                {'name': 'Sentadilla', 'sets': 4, 'reps': '8-10', 'weight': 60},
                {'name': 'Press banca', 'sets': 4, 'reps': '8-10'},
                {
                  'name': 'Remo con barra',
                  'sets': 3,
                  'reps': '10',
                  'notes': 'Espalda neutra',
                },
              ],
            },
            {
              'day_of_week': 'Miércoles',
              'focus': 'Full body',
              'exercises': [
                {'name': 'Peso muerto', 'sets': 3, 'reps': '5'},
                {'name': 'Press militar', 'sets': 3, 'reps': '8-10'},
                {'name': 'Dominadas', 'sets': 3, 'reps': 'Al fallo'},
              ],
            },
            {
              'day_of_week': 'Viernes',
              'focus': 'Full body',
              'exercises': [
                {'name': 'Prensa de piernas', 'sets': 4, 'reps': '12'},
                {'name': 'Fondos en paralelas', 'sets': 3, 'reps': '10'},
                {'name': 'Curl de bíceps', 'sets': 3, 'reps': '12'},
                {'name': 'Plancha', 'duration': '3 x 45 s'},
              ],
            },
          ],
        },
      });

  /// Lee [source] y devuelve la rutina lista para guardar.
  ///
  /// Lanza [RoutineFormatException] con un mensaje en español cuando el JSON no
  /// se puede convertir en una rutina utilizable.
  static RoutineImportResult decode(String source) {
    final texto = source.trim();
    if (texto.isEmpty) {
      throw const RoutineFormatException('No hay nada que importar.');
    }
    if (texto.length > maxCaracteres) {
      throw const RoutineFormatException(
        'El JSON es demasiado grande (más de 512 KB). ¿Seguro que es una rutina?',
      );
    }

    final Object? crudo;
    try {
      crudo = jsonDecode(texto);
    } on FormatException catch (e) {
      throw RoutineFormatException(
        'El texto no es un JSON válido: ${_motivoJson(e)}',
      );
    }

    final avisos = <String>[];
    final Map<String, dynamic> rutina;

    if (crudo is List) {
      // Alguien pega solo la lista de días. Se acepta, porque es un error
      // fácil de cometer y la intención no es ambigua.
      rutina = {'days': crudo};
      avisos.add('El JSON era solo la lista de días: le he puesto un nombre.');
    } else if (crudo is Map) {
      final mapa = crudo.cast<String, dynamic>();
      // Formato envuelto (`{formato, version, rutina: {...}}`) o rutina pelada.
      final envuelta = mapa['rutina'] ?? mapa['routine'];
      rutina = envuelta is Map
          ? envuelta.cast<String, dynamic>()
          : mapa;
    } else {
      throw const RoutineFormatException(
        'El JSON tiene que ser un objeto con la rutina, no un valor suelto.',
      );
    }

    final nombre = _texto(_campo(rutina, const ['name', 'nombre']), 120) ??
        (crudo is List ? 'Rutina importada' : null);
    if (nombre == null) {
      throw const RoutineFormatException(
        'Falta el nombre de la rutina (campo "name" o "nombre").',
      );
    }

    final actividadCruda = _texto(
      _campo(rutina, const [
        'activity_type',
        'activityType',
        'tipo',
        'tipo_actividad',
      ]),
      60,
    );
    final actividad = _normalizarActividad(actividadCruda);
    if (actividad == null) {
      avisos.add(
        actividadCruda == null
            ? 'Sin tipo de actividad: la guardo como gimnasio.'
            : 'Tipo de actividad desconocido ("$actividadCruda"): la guardo como gimnasio.',
      );
    }

    final diasCrudos =
        _campo(rutina, const ['days', 'dias', 'días', 'dias_entrenamiento']);
    if (diasCrudos is! List || diasCrudos.isEmpty) {
      throw const RoutineFormatException(
        'La rutina no tiene días (campo "days" o "dias" con al menos un día).',
      );
    }

    // Los días se acumulan por su nombre ya normalizado: dos bloques para el
    // mismo día se funden en uno. Guardarlos por separado deja dos filas
    // "Lunes" y la app solo mira la primera (`days.indexWhere`), así que la
    // mitad de los ejercicios desaparecerían de la vista sin decir nada.
    final porDia = <String, RoutineDay>{};
    for (var i = 0; i < diasCrudos.length; i++) {
      final crudoDia = diasCrudos[i];
      if (crudoDia is! Map) {
        throw RoutineFormatException(
          'El día ${i + 1} no es un objeto JSON.',
        );
      }
      final dia = crudoDia.cast<String, dynamic>();
      final etiqueta = _normalizarDia(
        _campo(dia, const ['day_of_week', 'dayOfWeek', 'dia', 'día', 'dia_semana']),
      );
      if (etiqueta == null) {
        throw RoutineFormatException(
          'El día ${i + 1} no tiene un día de la semana válido. Usa Lunes, '
          'Martes, Miércoles, Jueves, Viernes, Sábado o Domingo.',
        );
      }

      final focus = _texto(_campo(dia, const ['focus', 'enfoque', 'objetivo']), 120);
      final ejerciciosCrudos =
          _campo(dia, const ['exercises', 'ejercicios']) ?? const [];
      if (ejerciciosCrudos is! List) {
        throw RoutineFormatException(
          'Los ejercicios de $etiqueta tienen que ser una lista.',
        );
      }

      final ejercicios = <Exercise>[];
      for (final crudoEj in ejerciciosCrudos) {
        if (crudoEj is! Map) {
          avisos.add('$etiqueta: he saltado un ejercicio que no era un objeto.');
          continue;
        }
        final ejercicio = _leerEjercicio(
          crudoEj.cast<String, dynamic>(),
          etiqueta,
          avisos,
        );
        if (ejercicio != null) ejercicios.add(ejercicio);
      }

      final existente = porDia[etiqueta];
      if (existente == null) {
        porDia[etiqueta] =
            RoutineDay(dayOfWeek: etiqueta, focus: focus, exercises: ejercicios);
      } else {
        avisos.add('Había dos bloques para $etiqueta: los he juntado en uno.');
        porDia[etiqueta] = existente.copyWith(
          focus: existente.focus ?? focus,
          exercises: [...existente.exercises, ...ejercicios],
        );
      }
    }

    // En orden de semana, no en el que viniera el archivo: la pantalla de
    // rutina los pinta en el orden en que llegan.
    final dias = [
      for (final etiqueta in diasSemana)
        if (porDia.containsKey(etiqueta)) porDia[etiqueta]!,
    ];

    if (dias.every((d) => d.exercises.isEmpty)) {
      throw const RoutineFormatException(
        'Ningún día trae ejercicios con nombre.',
      );
    }

    return RoutineImportResult(
      routine: Routine(
        name: nombre,
        activityType: actividad ?? actividadPorDefecto,
        description: _texto(
          _campo(rutina, const ['description', 'descripcion', 'descripción', 'notas']),
          255,
        ),
        days: dias,
      ),
      warnings: avisos,
    );
  }

  static Exercise? _leerEjercicio(
    Map<String, dynamic> crudo,
    String etiquetaDia,
    List<String> avisos,
  ) {
    final nombre =
        _texto(_campo(crudo, const ['name', 'nombre', 'ejercicio']), 120);
    if (nombre == null) {
      avisos.add('$etiquetaDia: he saltado un ejercicio sin nombre.');
      return null;
    }

    final seriesCrudo = _campo(crudo, const ['sets', 'series']);
    final series = _entero(seriesCrudo);
    if (seriesCrudo != null && series == null) {
      avisos.add('$etiquetaDia · $nombre: no entendí las series ("$seriesCrudo").');
    }

    final pesoCrudo = _campo(crudo, const ['weight', 'peso', 'peso_kg']);
    final peso = _decimal(pesoCrudo);
    if (pesoCrudo != null && peso == null) {
      avisos.add('$etiquetaDia · $nombre: no entendí el peso ("$pesoCrudo").');
    }

    return Exercise(
      name: nombre,
      sets: series,
      reps: _texto(_campo(crudo, const ['reps', 'repeticiones']), 40),
      weight: peso,
      duration: _texto(
        _campo(crudo, const ['duration', 'duracion', 'duración', 'tiempo']),
        40,
      ),
      notes: _texto(_campo(crudo, const ['notes', 'notas', 'nota']), 1000),
    );
  }

  /// Primer valor no nulo de [claves] en [mapa].
  static Object? _campo(Map<String, dynamic> mapa, List<String> claves) {
    for (final clave in claves) {
      final valor = mapa[clave];
      if (valor != null) return valor;
    }
    return null;
  }

  /// Texto recortado a [maxLongitud], o null si no queda nada.
  ///
  /// Acepta números porque un JSON escrito a mano trae `"reps": 12` tan a
  /// menudo como `"reps": "12"`.
  static String? _texto(Object? valor, int maxLongitud) {
    if (valor == null) return null;
    if (valor is Map || valor is List) return null;
    final texto = valor.toString().trim();
    if (texto.isEmpty) return null;
    return texto.length > maxLongitud
        ? texto.substring(0, maxLongitud).trimRight()
        : texto;
  }

  static int? _entero(Object? valor) {
    if (valor is int) return valor > 0 ? valor : null;
    if (valor is num) return valor > 0 ? valor.round() : null;
    if (valor is String) {
      // "4 series" → 4. El primer número del texto es el que interesa.
      final m = RegExp(r'\d+').firstMatch(valor);
      final n = m == null ? null : int.tryParse(m.group(0)!);
      return (n != null && n > 0) ? n : null;
    }
    return null;
  }

  static double? _decimal(Object? valor) {
    if (valor is num) return valor > 0 ? valor.toDouble() : null;
    if (valor is String) {
      // "62,5 kg" → 62.5: la coma decimal es lo normal escribiendo en español.
      final m = RegExp(r'\d+(?:[.,]\d+)?').firstMatch(valor);
      if (m == null) return null;
      final n = double.tryParse(m.group(0)!.replaceAll(',', '.'));
      return (n != null && n > 0) ? n : null;
    }
    return null;
  }

  /// Devuelve el tipo de actividad canónico, o null si no se reconoce.
  static String? _normalizarActividad(String? valor) {
    if (valor == null) return null;
    final v = _sinTildes(valor);
    for (final entrada in _alias.entries) {
      if (entrada.value.contains(v)) return entrada.key;
    }
    return null;
  }

  static const Map<String, List<String>> _alias = {
    'gym': ['gym', 'gimnasio', 'pesas', 'musculacion', 'fuerza', 'hipertrofia'],
    'cardio': ['cardio', 'running', 'correr', 'bici', 'ciclismo', 'resistencia'],
    'calistenia': ['calistenia', 'calisthenics', 'peso corporal', 'bodyweight'],
    'yoga': ['yoga', 'pilates', 'yoga / pilates', 'movilidad', 'estiramientos'],
    'deportes': ['deportes', 'deporte', 'sports', 'futbol', 'baloncesto', 'padel'],
  };

  /// Convierte lo que venga en uno de los siete días exactos que espera la app.
  static String? _normalizarDia(Object? valor) {
    if (valor == null) return null;
    if (valor is num) {
      final n = valor.toInt();
      return (n >= 1 && n <= 7) ? diasSemana[n - 1] : null;
    }
    final v = _sinTildes(valor.toString());
    if (v.isEmpty) return null;
    final indice = _aliasDias.indexWhere((alias) => alias.contains(v));
    if (indice >= 0) return diasSemana[indice];
    final n = int.tryParse(v);
    if (n != null && n >= 1 && n <= 7) return diasSemana[n - 1];
    return null;
  }

  /// Alias aceptados por día, en el mismo orden que [diasSemana]: nombre
  /// entero, abreviado de tres letras e inglés (una rutina exportada de otra
  /// app viene en inglés más veces de las que parece).
  static const List<List<String>> _aliasDias = [
    ['lunes', 'lun', 'monday', 'mon'],
    ['martes', 'mar', 'tuesday', 'tue'],
    ['miercoles', 'mie', 'wednesday', 'wed'],
    ['jueves', 'jue', 'thursday', 'thu'],
    ['viernes', 'vie', 'friday', 'fri'],
    ['sabado', 'sab', 'saturday', 'sat'],
    ['domingo', 'dom', 'sunday', 'sun'],
  ];

  /// Minúsculas sin tildes. Dart no trae normalización Unicode, y aquí solo
  /// hacen falta las vocales acentuadas y la diéresis.
  static String _sinTildes(String valor) {
    const acentuadas = 'áàäâéèëêíìïîóòöôúùüû';
    const llanas = 'aaaaeeeeiiiioooouuuu';
    final buffer = StringBuffer();
    for (final rune in valor.trim().toLowerCase().runes) {
      final caracter = String.fromCharCode(rune);
      final i = acentuadas.indexOf(caracter);
      buffer.write(i >= 0 ? llanas[i] : caracter);
    }
    return buffer.toString();
  }

  /// El mensaje de `jsonDecode` trae el offset, que sí ayuda a encontrar la
  /// coma de más; el resto del `toString()` es ruido para quien lo lee.
  static String _motivoJson(FormatException e) {
    final offset = e.offset;
    return offset == null
        ? e.message
        : '${e.message} (carácter $offset)';
  }
}
