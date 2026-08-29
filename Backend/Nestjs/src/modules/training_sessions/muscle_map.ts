/// Reparto de la carga de un ejercicio entre grupos musculares, y cuánto
/// volumen semanal es "lo normal" en cada uno. Es la mitad offline del mapa de
/// calor corporal: `training_session.service.ts` solo suma series, aquí está
/// todo el conocimiento de qué músculo trabaja cada cosa.
///
/// Vive en un archivo propio y no dentro del servicio porque el mismo reparto
/// lo pide cualquiera que quiera razonar sobre volumen por músculo (el revisor
/// de rutina de la IA es el candidato obvio), y porque es una tabla de datos:
/// crece añadiendo filas, no lógica.

/// Los 16 músculos que dibuja el mapa corporal del frontend. Las mismas claves
/// exactas están en `body_map_paths.dart`: cambiar una aquí sin cambiarla allí
/// deja ese músculo pintado siempre en frío, sin ningún error visible.
export const MUSCULOS = {
  pecho: 'Pecho',
  dorsal: 'Dorsal',
  trapecio: 'Trapecio',
  lumbar: 'Lumbar',
  hombro_anterior: 'Deltoides anterior',
  hombro_lateral: 'Deltoides lateral',
  hombro_posterior: 'Deltoides posterior',
  biceps: 'Bíceps',
  triceps: 'Tríceps',
  antebrazo: 'Antebrazo',
  abdomen: 'Abdomen',
  gluteos: 'Glúteos',
  cuadriceps: 'Cuádriceps',
  isquiotibiales: 'Isquiotibiales',
  aductores: 'Aductores',
  gemelos: 'Gemelos',
} as const;

export type MuscleId = keyof typeof MUSCULOS;
export type Reparto = Partial<Record<MuscleId, number>>;

/// Series semanales por músculo que la literatura de hipertrofia sitúa como
/// rango efectivo (Schoenfeld et al. 2017, meta-análisis dosis-respuesta;
/// Israetel/RP para el reparto por músculo). Sirven para dos cosas:
///
///  1. **Normalizar el color.** El gradiente se calcula contra el extremo alto
///     del rango, no contra el máximo del propio usuario. Escalar contra el
///     máximo propio pintaría idéntica una semana floja y una brutal — el rojo
///     saldría igual en las dos, porque el máximo también baja.
///  2. **Etiquetar cada músculo** como bajo / en rango / por encima en el
///     detalle, que es la lectura accionable ("te falta espalda esta semana").
export const SERIES_SEMANA: Record<MuscleId, { min: number; max: number }> = {
  pecho: { min: 10, max: 20 },
  dorsal: { min: 10, max: 20 },
  trapecio: { min: 6, max: 14 },
  lumbar: { min: 4, max: 10 },
  hombro_anterior: { min: 6, max: 14 },
  hombro_lateral: { min: 8, max: 18 },
  hombro_posterior: { min: 6, max: 16 },
  biceps: { min: 8, max: 16 },
  triceps: { min: 8, max: 16 },
  antebrazo: { min: 4, max: 12 },
  abdomen: { min: 6, max: 16 },
  gluteos: { min: 8, max: 16 },
  cuadriceps: { min: 10, max: 20 },
  isquiotibiales: { min: 8, max: 16 },
  aductores: { min: 4, max: 10 },
  gemelos: { min: 8, max: 16 },
};

/// Vida media de la fatiga, en horas. Un músculo grande cargado con una serie
/// pesada sigue pesando dos días después; el antebrazo o el gemelo, no. Es lo
/// que hace que la vista "fatiga" no sea el volumen otra vez con otro nombre:
/// dos sesiones idénticas separadas por cinco días dan el mismo volumen y
/// fatiga casi nula, y eso es exactamente lo que se quiere ver antes de
/// decidir qué entrenar hoy.
export const VIDA_MEDIA_HORAS: Record<MuscleId, number> = {
  pecho: 48,
  dorsal: 54,
  trapecio: 40,
  lumbar: 60,
  hombro_anterior: 36,
  hombro_lateral: 32,
  hombro_posterior: 32,
  biceps: 36,
  triceps: 36,
  antebrazo: 24,
  abdomen: 30,
  gluteos: 48,
  cuadriceps: 60,
  isquiotibiales: 60,
  aductores: 48,
  gemelos: 30,
};

/// Reparto por grupo del catálogo (`Ejercicios_Catalogo.grupo_muscular`). Es el
/// respaldo cuando el nombre del ejercicio no encaja con ningún patrón: el
/// catálogo solo distingue siete grupos, así que "Piernas" tiene que repartirse
/// entre los cuatro músculos que casi siempre implica.
const GRUPO_CATALOGO: Record<string, Reparto> = {
  pecho: { pecho: 1, hombro_anterior: 0.4, triceps: 0.35 },
  espalda: { dorsal: 1, trapecio: 0.5, biceps: 0.4, lumbar: 0.3 },
  hombros: { hombro_anterior: 0.8, hombro_lateral: 1, hombro_posterior: 0.5, trapecio: 0.3 },
  biceps: { biceps: 1, antebrazo: 0.4 },
  triceps: { triceps: 1 },
  piernas: { cuadriceps: 1, isquiotibiales: 0.6, gluteos: 0.6, gemelos: 0.3 },
  core: { abdomen: 1, lumbar: 0.3 },
  gluteos: { gluteos: 1, isquiotibiales: 0.5 },
  brazos: { biceps: 1, triceps: 1, antebrazo: 0.4 },
  antebrazo: { antebrazo: 1 },
  cardio: { cuadriceps: 0.8, isquiotibiales: 0.6, gluteos: 0.6, gemelos: 0.8 },
  // Grupos que llegaron con la importación de free-exercise-db (migración
  // 1787100000000). El dataset distingue el músculo primario de verdad, no los
  // siete cajones del catálogo original, así que aquí el reparto puede ser
  // directo en vez de repartido: si el ejercicio dice "isquiotibiales", son
  // isquiotibiales. Sin estas entradas el ejercicio no falla — se pinta gris,
  // que es peor, porque parece que no lo entrenaste.
  cuadriceps: { cuadriceps: 1, gluteos: 0.3 },
  isquiotibiales: { isquiotibiales: 1, gluteos: 0.4 },
  gemelos: { gemelos: 1 },
  lumbar: { lumbar: 1, gluteos: 0.3 },
  trapecio: { trapecio: 1, hombro_posterior: 0.3 },
  aductores: { aductores: 1, isquiotibiales: 0.2 },
  abductores: { gluteos: 1, aductores: 0.2 },
  // El cuello no está entre los 16 músculos que pinta el mapa. Se reparte al
  // trapecio, que es lo más cercano que sí se ve, en vez de dejarlo en nada.
  cuello: { trapecio: 0.6 },
  'cuerpo completo': {
    cuadriceps: 0.6, gluteos: 0.6, dorsal: 0.6, pecho: 0.5,
    hombro_anterior: 0.4, abdomen: 0.5, isquiotibiales: 0.4,
  },
};

/// Reparto por tipo de sesión, último recurso: una sesión de Health Connect
/// llega sin ejercicios, solo con `tipo_entrenamiento` y el nombre de la
/// actividad. Dejarla fuera del mapa sería peor que estimarla — es
/// precisamente el caso de quien sale a correr y no entiende por qué sus
/// gemelos aparecen en frío.
const TIPO_SESION: Record<string, Reparto> = {
  fuerza: {
    pecho: 0.6, dorsal: 0.6, cuadriceps: 0.6, isquiotibiales: 0.4,
    gluteos: 0.4, hombro_lateral: 0.4, biceps: 0.4, triceps: 0.4, abdomen: 0.3,
  },
  cardio: { gemelos: 1, cuadriceps: 0.8, isquiotibiales: 0.6, gluteos: 0.6 },
  flexibilidad: {
    isquiotibiales: 0.6, lumbar: 0.5, gluteos: 0.5, aductores: 0.4,
    abdomen: 0.4, hombro_posterior: 0.3,
  },
};

interface Patron {
  claves: string[];
  reparto: Reparto;
}

/// Patrones por nombre de ejercicio. Gana el que case con más claves, así que
/// "curl femoral" (2 claves) se lleva los isquios y no el bíceps de "curl"
/// (1 clave) — el orden de la lista no importa, la especificidad sí.
///
/// Las claves se comparan como **palabra completa** sobre el nombre
/// normalizado (minúsculas, sin tildes). No es un detalle: con `includes` a
/// secas, "remo" casa dentro de "remordimiento" y, peor en este dominio,
/// "curl" dentro de cualquier cosa. El mismo error que ya costó caro en
/// `clinical_reference.normalizar_codigo` con los símbolos químicos.
const PATRONES: Patron[] = [
  // ── Pecho ──
  { claves: ['press', 'banca'], reparto: { pecho: 1, triceps: 0.4, hombro_anterior: 0.35 } },
  { claves: ['press', 'inclinado'], reparto: { pecho: 1, hombro_anterior: 0.5, triceps: 0.35 } },
  { claves: ['press', 'declinado'], reparto: { pecho: 1, triceps: 0.4 } },
  { claves: ['press', 'pecho'], reparto: { pecho: 1, triceps: 0.4, hombro_anterior: 0.35 } },
  { claves: ['aperturas'], reparto: { pecho: 1, hombro_anterior: 0.3 } },
  { claves: ['apertura'], reparto: { pecho: 1, hombro_anterior: 0.3 } },
  { claves: ['cruces'], reparto: { pecho: 1, hombro_anterior: 0.3 } },
  { claves: ['contractor'], reparto: { pecho: 1 } },
  { claves: ['peck', 'deck'], reparto: { pecho: 1 } },
  { claves: ['flexiones'], reparto: { pecho: 1, triceps: 0.5, hombro_anterior: 0.4, abdomen: 0.3 } },
  { claves: ['pullover'], reparto: { dorsal: 1, pecho: 0.6, triceps: 0.3 } },

  // ── Espalda ──
  { claves: ['dominadas'], reparto: { dorsal: 1, biceps: 0.5, trapecio: 0.3, antebrazo: 0.3 } },
  { claves: ['dominada'], reparto: { dorsal: 1, biceps: 0.5, trapecio: 0.3, antebrazo: 0.3 } },
  { claves: ['jalon'], reparto: { dorsal: 1, biceps: 0.45, trapecio: 0.3 } },
  { claves: ['remo'], reparto: { dorsal: 1, trapecio: 0.6, biceps: 0.4, hombro_posterior: 0.4, lumbar: 0.3 } },
  { claves: ['peso', 'muerto'], reparto: { isquiotibiales: 1, gluteos: 0.9, lumbar: 0.9, trapecio: 0.5, dorsal: 0.4, antebrazo: 0.4, cuadriceps: 0.3 } },
  { claves: ['peso', 'muerto', 'rumano'], reparto: { isquiotibiales: 1, gluteos: 0.8, lumbar: 0.7, antebrazo: 0.3 } },
  { claves: ['encogimientos'], reparto: { trapecio: 1, antebrazo: 0.3 } },
  { claves: ['shrug'], reparto: { trapecio: 1, antebrazo: 0.3 } },
  { claves: ['face', 'pull'], reparto: { hombro_posterior: 1, trapecio: 0.6 } },
  { claves: ['pajaro'], reparto: { hombro_posterior: 1, trapecio: 0.4 } },
  { claves: ['hiperextensiones'], reparto: { lumbar: 1, gluteos: 0.6, isquiotibiales: 0.6 } },
  { claves: ['buenos', 'dias'], reparto: { isquiotibiales: 1, lumbar: 0.9, gluteos: 0.6 } },

  // ── Hombros ──
  { claves: ['press', 'militar'], reparto: { hombro_anterior: 1, hombro_lateral: 0.6, triceps: 0.5, trapecio: 0.3 } },
  { claves: ['press', 'hombro'], reparto: { hombro_anterior: 1, hombro_lateral: 0.6, triceps: 0.45, trapecio: 0.3 } },
  { claves: ['press', 'arnold'], reparto: { hombro_anterior: 1, hombro_lateral: 0.7, triceps: 0.4 } },
  { claves: ['elevaciones', 'laterales'], reparto: { hombro_lateral: 1, trapecio: 0.3 } },
  { claves: ['elevaciones', 'frontales'], reparto: { hombro_anterior: 1, pecho: 0.3 } },
  { claves: ['remo', 'menton'], reparto: { hombro_lateral: 1, trapecio: 0.7, biceps: 0.3 } },

  // ── Brazos ──
  { claves: ['curl'], reparto: { biceps: 1, antebrazo: 0.5 } },
  { claves: ['curl', 'martillo'], reparto: { biceps: 1, antebrazo: 0.7 } },
  { claves: ['curl', 'predicador'], reparto: { biceps: 1, antebrazo: 0.4 } },
  { claves: ['curl', 'concentrado'], reparto: { biceps: 1 } },
  { claves: ['triceps'], reparto: { triceps: 1 } },
  { claves: ['press', 'frances'], reparto: { triceps: 1 } },
  { claves: ['fondos'], reparto: { triceps: 1, pecho: 0.7, hombro_anterior: 0.4 } },
  { claves: ['patada', 'triceps'], reparto: { triceps: 1 } },
  { claves: ['rompecraneos'], reparto: { triceps: 1 } },
  { claves: ['muneca'], reparto: { antebrazo: 1 } },
  { claves: ['antebrazo'], reparto: { antebrazo: 1 } },
  { claves: ['agarre'], reparto: { antebrazo: 1 } },

  // ── Piernas ──
  { claves: ['sentadilla'], reparto: { cuadriceps: 1, gluteos: 0.7, aductores: 0.4, lumbar: 0.3, abdomen: 0.3 } },
  { claves: ['sentadilla', 'bulgara'], reparto: { cuadriceps: 1, gluteos: 0.9, isquiotibiales: 0.4, aductores: 0.3 } },
  { claves: ['sentadilla', 'sumo'], reparto: { cuadriceps: 0.9, aductores: 1, gluteos: 0.8 } },
  { claves: ['sentadilla', 'hack'], reparto: { cuadriceps: 1, gluteos: 0.5 } },
  { claves: ['prensa'], reparto: { cuadriceps: 1, gluteos: 0.6, isquiotibiales: 0.3 } },
  { claves: ['extension', 'cuadriceps'], reparto: { cuadriceps: 1 } },
  { claves: ['extensiones', 'cuadriceps'], reparto: { cuadriceps: 1 } },
  { claves: ['curl', 'femoral'], reparto: { isquiotibiales: 1, gemelos: 0.3 } },
  { claves: ['femoral'], reparto: { isquiotibiales: 1, gemelos: 0.3 } },
  { claves: ['zancadas'], reparto: { cuadriceps: 1, gluteos: 0.8, isquiotibiales: 0.4 } },
  { claves: ['zancada'], reparto: { cuadriceps: 1, gluteos: 0.8, isquiotibiales: 0.4 } },
  { claves: ['lunge'], reparto: { cuadriceps: 1, gluteos: 0.8, isquiotibiales: 0.4 } },
  { claves: ['hip', 'thrust'], reparto: { gluteos: 1, isquiotibiales: 0.5 } },
  { claves: ['puente', 'gluteo'], reparto: { gluteos: 1, isquiotibiales: 0.4 } },
  { claves: ['patada', 'gluteo'], reparto: { gluteos: 1 } },
  { claves: ['abduccion'], reparto: { gluteos: 1 } },
  { claves: ['aduccion'], reparto: { aductores: 1 } },
  { claves: ['aductor'], reparto: { aductores: 1 } },
  { claves: ['gemelos'], reparto: { gemelos: 1 } },
  { claves: ['gemelo'], reparto: { gemelos: 1 } },
  { claves: ['calf'], reparto: { gemelos: 1 } },
  { claves: ['soleo'], reparto: { gemelos: 1 } },
  { claves: ['subida', 'cajon'], reparto: { cuadriceps: 1, gluteos: 0.7 } },
  { claves: ['step', 'up'], reparto: { cuadriceps: 1, gluteos: 0.7 } },

  // ── Core ──
  { claves: ['plancha'], reparto: { abdomen: 1, lumbar: 0.4, hombro_anterior: 0.3 } },
  { claves: ['crunch'], reparto: { abdomen: 1 } },
  { claves: ['abdominales'], reparto: { abdomen: 1 } },
  { claves: ['abdominal'], reparto: { abdomen: 1 } },
  { claves: ['elevacion', 'piernas'], reparto: { abdomen: 1 } },
  { claves: ['elevaciones', 'piernas'], reparto: { abdomen: 1 } },
  { claves: ['rueda', 'abdominal'], reparto: { abdomen: 1, dorsal: 0.4 } },
  { claves: ['russian', 'twist'], reparto: { abdomen: 1 } },
  { claves: ['giros', 'rusos'], reparto: { abdomen: 1 } },
  { claves: ['mountain', 'climbers'], reparto: { abdomen: 1, hombro_anterior: 0.3 } },
  { claves: ['pallof'], reparto: { abdomen: 1, lumbar: 0.3 } },

  // ── Cardio y actividades (llegan como `fuente` de Health Connect) ──
  { claves: ['correr'], reparto: { gemelos: 1, cuadriceps: 0.8, isquiotibiales: 0.7, gluteos: 0.6 } },
  { claves: ['carrera'], reparto: { gemelos: 1, cuadriceps: 0.8, isquiotibiales: 0.7, gluteos: 0.6 } },
  { claves: ['running'], reparto: { gemelos: 1, cuadriceps: 0.8, isquiotibiales: 0.7, gluteos: 0.6 } },
  { claves: ['trote'], reparto: { gemelos: 1, cuadriceps: 0.8, isquiotibiales: 0.7, gluteos: 0.6 } },
  { claves: ['caminar'], reparto: { gemelos: 0.6, cuadriceps: 0.4, gluteos: 0.4 } },
  { claves: ['marcha'], reparto: { gemelos: 0.6, cuadriceps: 0.4, gluteos: 0.4 } },
  { claves: ['senderismo'], reparto: { cuadriceps: 0.8, gluteos: 0.7, gemelos: 0.7, isquiotibiales: 0.5 } },
  { claves: ['bicicleta'], reparto: { cuadriceps: 1, gluteos: 0.6, isquiotibiales: 0.5, gemelos: 0.4 } },
  { claves: ['ciclismo'], reparto: { cuadriceps: 1, gluteos: 0.6, isquiotibiales: 0.5, gemelos: 0.4 } },
  { claves: ['spinning'], reparto: { cuadriceps: 1, gluteos: 0.6, isquiotibiales: 0.5, gemelos: 0.4 } },
  { claves: ['eliptica'], reparto: { cuadriceps: 0.8, isquiotibiales: 0.6, gluteos: 0.6, gemelos: 0.5 } },
  { claves: ['escaladora'], reparto: { cuadriceps: 0.8, gluteos: 0.8, gemelos: 0.6 } },
  { claves: ['natacion'], reparto: { dorsal: 1, hombro_posterior: 0.7, hombro_lateral: 0.6, triceps: 0.5, pecho: 0.5, abdomen: 0.4 } },
  { claves: ['comba'], reparto: { gemelos: 1, cuadriceps: 0.4 } },
  { claves: ['burpees'], reparto: { cuadriceps: 0.7, pecho: 0.6, abdomen: 0.6, triceps: 0.5, hombro_anterior: 0.4 } },
  { claves: ['boxeo'], reparto: { hombro_anterior: 0.8, hombro_lateral: 0.6, abdomen: 0.7, pecho: 0.5, gemelos: 0.5 } },
  { claves: ['yoga'], reparto: { isquiotibiales: 0.6, lumbar: 0.5, abdomen: 0.5, gluteos: 0.4, aductores: 0.4 } },
];

/// Minúsculas y sin tildes, que es la forma en la que se comparan claves y
/// nombres. `ñ` cae a `n` a propósito: "muñeca" y "muneca" tienen que ser la
/// misma palabra, y nadie escribe el nombre de un ejercicio dos veces igual.
export function normalizar(texto: string): string {
  return texto
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .trim();
}

/// Palabra completa, no subcadena. Ver la nota de `PATRONES`.
function contienePalabra(texto: string, palabra: string): boolean {
  return new RegExp(`(^|[^a-z0-9])${palabra}([^a-z0-9]|$)`).test(texto);
}

/// Reparto de un ejercicio a partir de su nombre. `null` si ningún patrón casa
/// — quien llama decide entonces si tira del catálogo o del tipo de sesión.
export function repartoPorNombre(nombre: string): Reparto | null {
  const texto = normalizar(nombre);
  if (!texto) return null;

  let mejor: Patron | null = null;
  for (const patron of PATRONES) {
    if (!patron.claves.every((clave) => contienePalabra(texto, clave))) continue;
    if (!mejor || patron.claves.length > mejor.claves.length) mejor = patron;
  }
  return mejor?.reparto ?? null;
}

/// Reparto a partir del grupo del catálogo (`Pecho`, `Piernas`, …).
export function repartoPorGrupo(grupo: string): Reparto | null {
  return GRUPO_CATALOGO[normalizar(grupo)] ?? null;
}

/// Reparto a partir del tipo de sesión (`fuerza`, `cardio`, `flexibilidad`).
export function repartoPorTipo(tipo: string): Reparto {
  return TIPO_SESION[normalizar(tipo)] ?? TIPO_SESION.fuerza;
}

export const IDS_MUSCULOS = Object.keys(MUSCULOS) as MuscleId[];

/// Series que se le suponen a un ejercicio de rutina que no las declara.
/// `Exercise.sets` es nullable y una rutina escrita a mano o dictada por chat
/// llega a menudo sin ese número. Tres es el mínimo con el que la literatura
/// de hipertrofia cuenta un ejercicio como trabajo real, así que erra por
/// abajo: inflar el plan haría que la pantalla avisara de sobreentrenamiento
/// que nadie ha escrito. Quien llama debe contar aparte cuánto volumen salió
/// de aquí — un plan hecho entero de defaults no mide la rutina, mide esto.
export const SERIES_POR_DEFECTO = 3;

/// A qué músculos va la carga de un ejercicio, en orden de confianza:
/// nombre reconocido → grupo del catálogo → tipo de sesión. `sin_clasificar`
/// recoge los nombres que no casaron con ninguna de las dos primeras vías,
/// para poder ampliar la tabla después con lo que de verdad entrena la gente
/// en vez de a ciegas.
///
/// El último escalón es opcional y ahí está toda la diferencia entre los dos
/// usos de esta función:
///
///  - **Sesión hecha** (`tipoSesion` con valor): `repartoPorTipo` nunca falla,
///    así que nunca devuelve `null` y toda sesión registrada pinta algo. Una
///    carrera sin ejercicios nombrados sigue siendo trabajo que existió.
///  - **Ejercicio planificado** (`tipoSesion` a `null`): devuelve `null` si no
///    casó nada. Un ejercicio de rutina no tiene "tipo de sesión" del que
///    tirar, y repartirlo a ojo inventaría volumen que el usuario no ha
///    escrito — justo lo que la pantalla del plan pretende medir.
///
/// Vive aquí y no en `TrainingSessionService` porque el módulo `routine` la
/// necesita igual, y duplicar los tres escalones dejaría dos definiciones de
/// "qué músculo trabaja este ejercicio" divergiendo en silencio.
export function repartoEjercicio(
  nombre: string | null,
  tipoSesion: string | null,
  catalogo: Map<string, string>,
  sinClasificar: Set<string>,
): Reparto | null {
  if (nombre) {
    const porNombre = repartoPorNombre(nombre);
    if (porNombre) return porNombre;

    const grupo = catalogo.get(normalizar(nombre));
    if (grupo) {
      const porGrupo = repartoPorGrupo(grupo);
      if (porGrupo) return porGrupo;
    }
    sinClasificar.add(nombre);
  }
  return tipoSesion === null ? null : repartoPorTipo(tipoSesion);
}
