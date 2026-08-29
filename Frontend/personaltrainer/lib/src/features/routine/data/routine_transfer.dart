/// Serializar una rutina para sacarla de la app y volver a meterla en otra
/// cuenta o en otro móvil.
///
/// Tres decisiones de formato:
///
///  - **El sobre lleva `formato` y `version`.** Sin ellos, pegar cualquier otro
///    JSON (una respuesta del backend, un fichero equivocado) daría una rutina
///    a medias en vez de un error legible, y no habría forma de rechazar un
///    fichero escrito por una versión futura de la app.
///  - **Se exporta sin identificadores.** Los `id` de rutina, día y ejercicio
///    son de la base de datos de quien exportó; importarlos apuntaría a filas
///    de otro usuario. La rutina importada es siempre una rutina nueva.
///  - **Al importar se remienda todo lo remendable.** El día que no case con un
///    día de la semana se coloca en el primero libre, el ejercicio sin nombre
///    se cae y el tipo de actividad desconocido pasa a `gym`. Rechazar el
///    fichero entero por un campo suelto obligaría a editar JSON a mano.
library;

import 'dart:convert';

import '../models/exercise.dart';
import '../models/routine.dart';
import '../models/routine_day.dart';


/// Marca del sobre. Cambiarla invalida los ficheros ya exportados, así que solo
/// se toca si el formato deja de ser compatible de verdad.
const String formatoRutina = 'personaltrainer.rutina';

/// Sube cuando el sobre cambie de forma. Un fichero con una versión mayor que
/// esta se rechaza: lo que trae de más no se sabe leer.
const int versionRutina = 1;

const List<String> _diasSemana = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];

const List<String> _actividades = [
  'gym',
  'cardio',
  'calistenia',
  'yoga',
  'deportes',
];

/// Error de importación con un mensaje ya redactado para enseñárselo al
/// usuario: la pantalla lo pinta tal cual en vez de traducir códigos.
class RutinaImportadaInvalida implements Exception {
  const RutinaImportadaInvalida(this.mensaje);

  final String mensaje;

  @override
  String toString() => mensaje;
}

/// JSON indentado con la rutina, listo para guardar en un fichero o copiar al
/// portapapeles. Indentado a propósito: se pega en un chat o en unas notas y
/// tiene que poderse leer por encima.
String exportarRutina(Routine routine) {
  final rutina = routine.toJson()..remove('id');
  for (final dia in (rutina['days'] as List).cast<Map<String, dynamic>>()) {
    dia.remove('id');
    for (final ej in (dia['exercises'] as List).cast<Map<String, dynamic>>()) {
      ej.remove('id');
    }
  }

  return const JsonEncoder.withIndent('  ').convert({
    'formato': formatoRutina,
    'version': versionRutina,
    'exportado_en': DateTime.now().toIso8601String(),
    'rutina': rutina,
  });
}

/// Nombre de fichero sugerido: el de la rutina en minúsculas y sin nada que
/// pueda molestar a un sistema de ficheros.
String nombreArchivoRutina(Routine routine) {
  final base = routine.name
      .toLowerCase()
      .replaceAll(RegExp(r'[áàä]'), 'a')
      .replaceAll(RegExp(r'[éèë]'), 'e')
      .replaceAll(RegExp(r'[íìï]'), 'i')
      .replaceAll(RegExp(r'[óòö]'), 'o')
      .replaceAll(RegExp(r'[úùü]'), 'u')
      .replaceAll('ñ', 'n')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return 'rutina-${base.isEmpty ? 'exportada' : base}.json';
}

/// Lee lo exportado por [exportarRutina] y devuelve una rutina **sin id**,
/// lista para crearse como nueva. Lanza [RutinaImportadaInvalida] con un
/// mensaje que se puede enseñar tal cual.
Routine importarRutina(String texto) {
  final recortado = texto.trim();
  if (recortado.isEmpty) {
    throw const RutinaImportadaInvalida('No has pegado nada.');
  }

  final Object? decodificado;
  try {
    decodificado = jsonDecode(recortado);
  } on FormatException {
    throw const RutinaImportadaInvalida(
      'Esto no es un archivo de rutina: el texto no es un JSON válido.',
    );
  }

  if (decodificado is! Map<String, dynamic>) {
    throw const RutinaImportadaInvalida(
      'Esto no es un archivo de rutina de Personal TrAIner.',
    );
  }

  final formato = decodificado['formato'];
  if (formato != null && formato != formatoRutina) {
    throw const RutinaImportadaInvalida(
      'El archivo es de otra aplicación, no de Personal TrAIner.',
    );
  }

  final version = decodificado['version'];
  if (version is int && version > versionRutina) {
    throw const RutinaImportadaInvalida(
      'La rutina se exportó con una versión más nueva de la app. '
      'Actualiza para poder importarla.',
    );
  }

  // El sobre es lo normal, pero también vale el objeto de la rutina pelado:
  // quien copia el JSON a mano se deja fuera el envoltorio la mitad de las
  // veces, y ahí dentro ya hay lo necesario para reconocerlo.
  final crudo = decodificado['rutina'] ?? decodificado;
  if (crudo is! Map<String, dynamic>) {
    throw const RutinaImportadaInvalida(
      'El archivo no contiene ninguna rutina.',
    );
  }

  final dias = crudo['days'];
  if (dias is! List || dias.isEmpty) {
    throw const RutinaImportadaInvalida(
      'La rutina no trae ningún día de entrenamiento.',
    );
  }

  final nombre = (crudo['name'] ?? '').toString().trim();
  final actividad = (crudo['activity_type'] ?? '').toString().trim();
  final descripcion = (crudo['description'] ?? '').toString().trim();

  final libres = List<String>.from(_diasSemana);
  final resultado = <RoutineDay>[];

  for (final dia in dias) {
    if (dia is! Map<String, dynamic>) continue;

    final etiqueta = (dia['day_of_week'] ?? '').toString().trim();
    // Un día repetido o con un nombre que no es de la semana ('Día 2', de las
    // rutinas que escribía la IA) se coloca en el primer hueco libre: la
    // pantalla del plan cruza `day_of_week` contra su lista fija y un valor
    // fuera de ella no se pinta en ningún sitio.
    final valido = _diasSemana.contains(etiqueta) && libres.contains(etiqueta);
    final asignado = valido
        ? etiqueta
        : (libres.isEmpty ? _diasSemana.last : libres.first);
    libres.remove(asignado);

    final ejerciciosCrudos = dia['exercises'];
    final ejercicios = <Exercise>[];
    if (ejerciciosCrudos is List) {
      for (final ej in ejerciciosCrudos) {
        if (ej is! Map<String, dynamic>) continue;
        if ((ej['name'] ?? '').toString().trim().isEmpty) continue;
        final copia = Map<String, dynamic>.from(ej)..remove('id');
        ejercicios.add(Exercise.fromJson(copia));
      }
    }

    final foco = (dia['focus'] ?? '').toString().trim();
    resultado.add(
      RoutineDay(
        dayOfWeek: asignado,
        focus: foco.isEmpty ? null : foco,
        exercises: ejercicios,
      ),
    );
  }

  if (resultado.isEmpty) {
    throw const RutinaImportadaInvalida(
      'La rutina no trae ningún día de entrenamiento.',
    );
  }

  // Se ordenan por día de la semana porque los huecos libres se reparten en
  // orden de aparición y el plan se lee de lunes a domingo.
  resultado.sort(
    (a, b) => _diasSemana
        .indexOf(a.dayOfWeek)
        .compareTo(_diasSemana.indexOf(b.dayOfWeek)),
  );

  return Routine(
    name: nombre.isEmpty ? 'Rutina importada' : nombre,
    activityType: _actividades.contains(actividad) ? actividad : 'gym',
    description: descripcion.isEmpty ? null : descripcion,
    days: resultado,
  );
}
