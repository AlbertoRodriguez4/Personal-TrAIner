/// Vocabulario de filtros del catálogo de ejercicios.
///
/// Existe porque el catálogo pasó de 19 ejercicios a ~890 al importar
/// `free-exercise-db`: con 19 bastaba una fila de chips con los siete grupos
/// que había, pero con 16 grupos esa fila se convierte en un carrusel
/// horizontal por el que hay que arrastrar para encontrar "Gemelos". La
/// jerarquía región → grupo devuelve la elección a un golpe de vista.
///
/// **Las regiones se declaran aquí y los grupos vienen de la base de datos.**
/// El emparejamiento es por nombre normalizado (minúsculas, sin tildes) porque
/// el catálogo tiene dos generaciones de filas conviviendo: las 19 escritas a
/// mano, con grupos gruesos como "Piernas", y las importadas, que distinguen
/// "Cuádriceps" de "Isquiotibiales". Un grupo que no encaje en ninguna región
/// no se pierde: aparece en [regionOtros].
library;

import 'exercise_catalog.dart';

const String filtroTodos = 'Todos';

/// Región del cuerpo → grupos musculares del catálogo que caen dentro.
///
/// El orden es el de la fila de chips y no es alfabético a propósito: va de
/// arriba abajo del cuerpo, que es como la gente busca. "Piernas" aparece
/// además como grupo suelto porque así es como están clasificados los 19
/// ejercicios originales, anteriores a la importación.
const Map<String, List<String>> regionesMusculares = {
  'Pecho': ['Pecho'],
  'Espalda': ['Espalda', 'Dorsal', 'Trapecio', 'Lumbar'],
  'Hombros': ['Hombros', 'Cuello'],
  'Brazos': ['Bíceps', 'Tríceps', 'Antebrazo', 'Brazos'],
  'Core': ['Core', 'Abdomen'],
  'Piernas': [
    'Piernas',
    'Cuádriceps',
    'Isquiotibiales',
    'Glúteos',
    'Gemelos',
    'Aductores',
    'Abductores',
  ],
  'Cardio': ['Cardio', 'Cuerpo completo'],
};

/// Cajón de sastre para grupos que la tabla de arriba no contempla. No debería
/// llenarse nunca, pero si el catálogo gana un grupo nuevo es preferible que
/// aparezca aquí a que desaparezca del filtro sin que nadie se entere.
const String regionOtros = 'Otros';

String normalizarFiltro(String texto) {
  const tildes = {
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ü': 'u',
    'ñ': 'n',
  };
  var salida = texto.toLowerCase().trim();
  tildes.forEach((con, sin) => salida = salida.replaceAll(con, sin));
  return salida;
}

final Map<String, String> _regionPorGrupo = {
  for (final entrada in regionesMusculares.entries)
    for (final grupo in entrada.value) normalizarFiltro(grupo): entrada.key,
};

/// Región a la que pertenece [grupoMuscular], o [regionOtros].
String regionDe(String grupoMuscular) =>
    _regionPorGrupo[normalizarFiltro(grupoMuscular)] ?? regionOtros;

/// Regiones que realmente tienen ejercicios, en el orden de declaración.
///
/// Se calcula sobre los datos y no se pinta la lista fija: una región vacía es
/// un chip que al pulsarlo no hace nada, y eso se lee como que la app está
/// rota.
List<String> regionesConEjercicios(List<ExerciseCatalog> ejercicios) {
  final presentes = ejercicios.map((e) => regionDe(e.grupoMuscular)).toSet();
  final orden = [
    ...regionesMusculares.keys.where(presentes.contains),
    if (presentes.contains(regionOtros)) regionOtros,
  ];
  return [filtroTodos, ...orden];
}

/// Grupos de [region] que tienen ejercicios, en el orden declarado.
///
/// Devuelve vacío cuando la región solo aporta un grupo (Pecho, Core): en ese
/// caso la segunda fila de chips no añade nada y esconderla ahorra una fila
/// entera de pantalla.
List<String> subgruposDe(String region, List<ExerciseCatalog> ejercicios) {
  final presentes = <String>{};
  for (final e in ejercicios) {
    if (regionDe(e.grupoMuscular) == region) presentes.add(e.grupoMuscular);
  }
  if (presentes.length < 2) return const [];

  final declarados = regionesMusculares[region] ?? const [];
  final ordenados = <String>[
    ...declarados.where(
      (g) => presentes.any((p) => normalizarFiltro(p) == normalizarFiltro(g)),
    ),
  ];
  // Cualquier grupo presente que no estuviera declarado va al final, para que
  // no se caiga del filtro.
  for (final p in presentes) {
    if (!ordenados.any((g) => normalizarFiltro(g) == normalizarFiltro(p))) {
      ordenados.add(p);
    }
  }
  return [filtroTodos, ...ordenados];
}

/// Equipamientos presentes, **ordenados por cuántos ejercicios tienen**.
///
/// Por frecuencia y no alfabéticamente: lo que se busca de verdad es "con
/// mancuernas" o "con barra", y en orden alfabético eso queda detrás de
/// "Balón medicinal" y "Bandas". "Peso corporal" se fuerza al principio porque
/// es el filtro que resuelve la pregunta más común de todas, entrenar sin
/// material.
List<String> equipamientosDe(List<ExerciseCatalog> ejercicios) {
  final cuenta = <String, int>{};
  for (final e in ejercicios) {
    final equipo = (e.equipamiento ?? '').trim();
    if (equipo.isEmpty) continue;
    cuenta[equipo] = (cuenta[equipo] ?? 0) + 1;
  }
  final ordenados = cuenta.keys.toList()
    ..sort((a, b) {
      final pesoA = normalizarFiltro(a) == 'peso corporal' ? 1 : 0;
      final pesoB = normalizarFiltro(b) == 'peso corporal' ? 1 : 0;
      if (pesoA != pesoB) return pesoB - pesoA;
      final porCuenta = cuenta[b]!.compareTo(cuenta[a]!);
      return porCuenta != 0 ? porCuenta : a.compareTo(b);
    });
  return [filtroTodos, ...ordenados];
}

/// Aplica los tres filtros más la búsqueda de texto.
///
/// El subgrupo manda sobre la región: si hay subgrupo elegido, la región ya
/// está implícita en él y volver a comprobarla solo cuesta trabajo.
List<ExerciseCatalog> filtrarEjercicios(
  List<ExerciseCatalog> ejercicios, {
  required String region,
  required String subgrupo,
  required String equipamiento,
  required String consulta,
}) {
  final q = normalizarFiltro(consulta);
  return ejercicios.where((e) {
    if (subgrupo != filtroTodos) {
      if (normalizarFiltro(e.grupoMuscular) != normalizarFiltro(subgrupo)) {
        return false;
      }
    } else if (region != filtroTodos && regionDe(e.grupoMuscular) != region) {
      return false;
    }

    if (equipamiento != filtroTodos &&
        normalizarFiltro(e.equipamiento ?? '') !=
            normalizarFiltro(equipamiento)) {
      return false;
    }

    if (q.isEmpty) return true;
    return normalizarFiltro(e.nombre).contains(q) ||
        normalizarFiltro(e.grupoMuscular).contains(q) ||
        normalizarFiltro(e.equipamiento ?? '').contains(q);
  }).toList();
}
