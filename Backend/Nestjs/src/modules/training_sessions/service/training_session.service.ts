import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { MoreThanOrEqual, Repository } from 'typeorm';
import { TrainingSession } from '../entities/training_session.entity';
import { CreateTrainingSessionDto } from '../dto/create-training-session.dto';
import { UpdateTrainingSessionDto } from '../dto/update-training-session.dto';
import { ExerciseCatalog } from '../../exercises_catalog/entities/exercise_catalog.entity';
import { User } from '../../identity/entities/user.entity';
import {
  IDS_MUSCULOS,
  MUSCULOS,
  MuscleId,
  Reparto,
  SERIES_SEMANA,
  VIDA_MEDIA_HORAS,
  normalizar,
  repartoPorGrupo,
  repartoPorNombre,
  repartoPorTipo,
} from '../muscle_map';

/// Campos numéricos que entran en la media del usuario para el análisis de una
/// sesión. Todos nullable en la entidad: una sesión narrada por chat puede no
/// traer ninguno, así que la media se calcula solo sobre las que sí lo traen,
/// no sobre "0 si falta" — eso hundiría la media de cualquiera que registre
/// alguna sesión sin banda BLE.
const CAMPOS_METRICA = [
  'duracion_minutos',
  'calorias_kcal',
  'frecuencia_cardiaca_media',
  'frecuencia_cardiaca_max',
  'distancia_km',
] as const;
type CampoMetrica = (typeof CAMPOS_METRICA)[number];

@Injectable()
export class TrainingSessionService {
  constructor(
    @InjectRepository(TrainingSession)
    private readonly trainingSessionRepository: Repository<TrainingSession>,
    @InjectRepository(ExerciseCatalog)
    private readonly exerciseCatalogRepository: Repository<ExerciseCatalog>,
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
  ) {}

  async create(dto: CreateTrainingSessionDto) {
    const entity = this.trainingSessionRepository.create({
      ...dto,
      fecha_programada: new Date(dto.fecha_programada),
      estado: dto.estado ?? 'pendiente',
    });
    return this.trainingSessionRepository.save(entity);
  }

  async findByUser(userId: string) {
    return this.trainingSessionRepository.find({
      where: { userId },
      order: { fecha_programada: 'DESC' },
    });
  }

  async findOne(id: string) {
    const trainingSession = await this.trainingSessionRepository.findOne({ where: { id } });
    if (!trainingSession) {
      throw new NotFoundException('Sesión de entrenamiento no encontrada.');
    }
    return trainingSession;
  }

  async markAsCompleted(id: string) {
    await this.findOne(id);
    await this.trainingSessionRepository.update(id, {
      estado: 'completado',
      fecha_finalizacion: new Date(),
    });
    return this.findOne(id);
  }

  async update(id: string, dto: UpdateTrainingSessionDto) {
    const trainingSession = await this.findOne(id);

    if (dto.userId !== undefined) {
      trainingSession.userId = dto.userId;
    }
    if (dto.fecha_programada !== undefined) {
      trainingSession.fecha_programada = new Date(dto.fecha_programada);
    }
    if (dto.tipo_entrenamiento !== undefined) {
      trainingSession.tipo_entrenamiento = dto.tipo_entrenamiento;
    }
    if (dto.ejercicios !== undefined) {
      trainingSession.ejercicios = dto.ejercicios;
    }
    if (dto.estado !== undefined) {
      trainingSession.estado = dto.estado;
    }
    if (dto.duracion_minutos !== undefined) {
      trainingSession.duracion_minutos = dto.duracion_minutos;
    }
    if (dto.calorias_kcal !== undefined) {
      trainingSession.calorias_kcal = dto.calorias_kcal;
    }
    if (dto.frecuencia_cardiaca_media !== undefined) {
      trainingSession.frecuencia_cardiaca_media = dto.frecuencia_cardiaca_media;
    }
    if (dto.frecuencia_cardiaca_max !== undefined) {
      trainingSession.frecuencia_cardiaca_max = dto.frecuencia_cardiaca_max;
    }
    if (dto.distancia_km !== undefined) {
      trainingSession.distancia_km = dto.distancia_km;
    }
    if (dto.origen !== undefined) {
      trainingSession.origen = dto.origen;
    }
    if (dto.origen_id !== undefined) {
      trainingSession.origen_id = dto.origen_id;
    }

    return this.trainingSessionRepository.save(trainingSession);
  }

  async remove(id: string) {
    const trainingSession = await this.findOne(id);
    await this.trainingSessionRepository.remove(trainingSession);
    return { message: 'Sesión de entrenamiento eliminada correctamente.' };
  }

  private num(valor: unknown): number | null {
    if (valor === null || valor === undefined || valor === '') return null;
    const parsed = Number(valor);
    return Number.isFinite(parsed) ? parsed : null;
  }

  private media(sesiones: TrainingSession[], campo: CampoMetrica): number | null {
    const valores = sesiones
      .map((s) => this.num(s[campo]))
      .filter((v): v is number => v !== null);
    if (!valores.length) return null;
    const suma = valores.reduce((a, b) => a + b, 0);
    return Math.round((suma / valores.length) * 10) / 10;
  }

  /// Cuánto se desvía el valor de esta sesión de la media del usuario, en %.
  /// null si falta cualquiera de los dos lados — no hay nada que comparar.
  private deltaPct(valorSesion: number | null, valorMedia: number | null): number | null {
    if (valorSesion === null || valorMedia === null || valorMedia === 0) return null;
    return Math.round(((valorSesion - valorMedia) / valorMedia) * 1000) / 10;
  }

  /// Sesión + la media del usuario en cada métrica + cuánto se desvía esta
  /// sesión de esa media. La media se calcula sobre TODAS sus sesiones
  /// completadas con el dato presente (de cualquier origen), no solo las
  /// del mismo tipo — comparar "esta sesión de cardio" contra "tu media
  /// general" es justo la pregunta que alguien se hace al terminar de
  /// entrenar, y trocearlo por tipo de entrenamiento dejaría la media casi
  /// siempre calculada sobre 1-2 sesiones.
  async getAnalysis(id: string, userId: string) {
    const sesion = await this.findOne(id);
    if (sesion.userId !== userId) {
      throw new ForbiddenException('Esta sesión no pertenece al usuario indicado.');
    }

    const completadas = await this.trainingSessionRepository.find({
      where: { userId, estado: 'completado' },
    });

    const mediaUsuario = Object.fromEntries(
      CAMPOS_METRICA.map((campo) => [campo, this.media(completadas, campo)]),
    ) as Record<CampoMetrica, number | null>;

    const deltaPct = Object.fromEntries(
      CAMPOS_METRICA.map((campo) => [
        campo,
        this.deltaPct(this.num(sesion[campo]), mediaUsuario[campo]),
      ]),
    ) as Record<CampoMetrica, number | null>;

    return {
      sesion,
      media_usuario: mediaUsuario,
      delta_pct: deltaPct,
      sesiones_analizadas: completadas.length,
    };
  }

  /* ══════════════════ Mapa de carga por grupo muscular ══════════════════ */

  /// Un entrenamiento de cardio no tiene series, pero sí carga los gemelos.
  /// Para que quepa en la misma unidad que la fuerza se convierte su duración
  /// a "series equivalentes" con esta constante — 8 min de trabajo continuo ≈
  /// 1 serie. Es una equivalencia declarada, no una medida: por eso el
  /// endpoint marca esas series en `series_estimadas` y la tarjeta lo dice.
  private static readonly MINUTOS_POR_SERIE_EQUIVALENTE = 8;

  /// Por debajo del 50 % de la FC máxima estimada no cuenta como esfuerzo; a
  /// partir del 90 % se considera intensidad máxima. Entre medias, lineal.
  /// La FC máxima sale de `220 - edad`, la misma fórmula que ya usa la sesión
  /// en vivo (`workout_session_provider.setUserAge`) — cambiarla aquí y no
  /// allí haría que la misma sesión se viera con dos intensidades distintas.
  private static readonly FC_MIN_ESFUERZO = 0.5;
  private static readonly FC_MAX_ESFUERZO = 0.9;

  /// RIR a partir del cual una serie deja de aportar intensidad. RIR 0 (fallo)
  /// = 1.0; RIR 5 o más = 0.
  private static readonly RIR_SIN_ESFUERZO = 5;

  private texto(valor: unknown): string | null {
    return typeof valor === 'string' && valor.trim() ? valor.trim() : null;
  }

  /// Nombre del ejercicio dentro de una entrada de `ejercicios`. La clave
  /// cambia según de dónde venga la sesión: `ejercicio` la rastreada en vivo,
  /// `fuente` la de Health Connect, y las narradas por chat lo que decidiera
  /// el modelo — de ahí la lista.
  private nombreEntrada(entrada: Record<string, unknown>): string | null {
    for (const clave of ['ejercicio', 'nombre', 'name', 'exercise', 'fuente', 'actividad']) {
      const valor = this.texto(entrada[clave]);
      if (valor) return valor;
    }
    return null;
  }

  /// Series que representa una entrada. Una entrada con `serie` (ordinal) es
  /// UNA serie: así las guarda la sesión en vivo, una fila por serie con su
  /// FC. Una entrada con `series` (cardinal) las trae ya contadas, que es como
  /// las narra el chat. Confundirlas convierte "4 series" en 1, o al revés.
  private seriesEntrada(entrada: Record<string, unknown>): number {
    for (const clave of ['series', 'sets', 'num_series', 'numero_series']) {
      const valor = this.num(entrada[clave]);
      if (valor !== null && valor > 0) return Math.min(valor, 20);
    }
    return 1;
  }

  /// Si la entrada dice algo sobre cuántas series fueron, del modo que sea:
  /// contándolas (`series: 4`) o siendo ella misma una (`serie: 3`). Lo que no
  /// lo dice es un ejercicio suelto por su nombre, o el `fuente` de una sesión
  /// de Health Connect.
  ///
  /// La distinción decide si la sesión se estima desde la duración, y es más
  /// afilada de lo que parece: una sesión rastreada en vivo guarda **una fila
  /// por serie**, así que ninguna de sus entradas tiene `series > 1`. Mirar
  /// solo eso daba una sesión de 12 series contadas por buena para estimar, y
  /// la reemplazaba por las 7,5 que salen de sus 60 minutos.
  private declaraSeries(entrada: Record<string, unknown>): boolean {
    for (const clave of ['series', 'sets', 'num_series', 'numero_series']) {
      const valor = this.num(entrada[clave]);
      if (valor !== null && valor > 0) return true;
    }
    return entrada.serie !== undefined || entrada.set !== undefined;
  }

  /// Intensidad 0-1 de una entrada, a partir del RIR estimado o de si llegó al
  /// fallo. `null` si la entrada no dice nada del esfuerzo — que es el caso de
  /// todo lo narrado por chat y de todo lo que llega de Health Connect.
  private intensidadEntrada(entrada: Record<string, unknown>): number | null {
    const rir = this.num(entrada.rir_estimado ?? entrada.rir);
    if (rir !== null) {
      const tope = TrainingSessionService.RIR_SIN_ESFUERZO;
      return Math.max(0, Math.min(1, (tope - rir) / tope));
    }
    if (entrada.al_fallo === true) return 1;
    return null;
  }

  /// Intensidad 0-1 de la sesión entera desde la FC media, para las sesiones
  /// que no traen RIR por serie. Necesita la edad: sin fecha de nacimiento no
  /// hay FC máxima estimada, y se devuelve `null` en vez de suponer una edad
  /// por defecto, que desplazaría la intensidad de todo el mapa a la vez.
  private intensidadPorFc(sesion: TrainingSession, edad: number | null): number | null {
    const fcMedia = this.num(sesion.frecuencia_cardiaca_media);
    if (fcMedia === null || edad === null || edad <= 0) return null;
    const fcMax = 220 - edad;
    if (fcMax <= 0) return null;
    const pct = fcMedia / fcMax;
    const min = TrainingSessionService.FC_MIN_ESFUERZO;
    const max = TrainingSessionService.FC_MAX_ESFUERZO;
    return Math.max(0, Math.min(1, (pct - min) / (max - min)));
  }

  /// A qué músculos va la carga de un ejercicio, en orden de confianza:
  /// nombre reconocido → grupo del catálogo → tipo de sesión. El último nunca
  /// falla, así que toda sesión pinta algo; `sin_clasificar` recoge los
  /// nombres que llegaron hasta ahí, para poder ampliar la tabla después con
  /// lo que de verdad entrena la gente en vez de a ciegas.
  private repartoEjercicio(
    nombre: string | null,
    tipoSesion: string,
    catalogo: Map<string, string>,
    sinClasificar: Set<string>,
  ): Reparto {
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
    return repartoPorTipo(tipoSesion);
  }

  /// Volumen, intensidad y fatiga acumulada por grupo muscular en una ventana
  /// de N días. Las tres salen del mismo recorrido porque comparten el reparto
  /// por músculo; separarlas en tres endpoints obligaría a releer y
  /// reclasificar las mismas sesiones tres veces.
  ///
  /// Solo entran sesiones completadas: una `pendiente` es un plan, y pintar de
  /// rojo un músculo por lo que el usuario *va* a entrenar el jueves convierte
  /// el mapa en otra vista de la rutina en vez de en un registro de lo hecho.
  async getMuscleLoad(userId: string, dias: number) {
    const ventana = Math.max(1, Math.min(365, Math.round(dias) || 7));
    const ahora = new Date();
    const desde = new Date(ahora.getTime() - ventana * 24 * 60 * 60 * 1000);

    const [sesiones, catalogoFilas, usuario] = await Promise.all([
      this.trainingSessionRepository.find({
        where: { userId, estado: 'completado', fecha_programada: MoreThanOrEqual(desde) },
        order: { fecha_programada: 'DESC' },
      }),
      this.exerciseCatalogRepository.find(),
      this.userRepository.findOne({ where: { id: userId } }),
    ]);

    const catalogo = new Map(
      catalogoFilas.map((e) => [normalizar(e.nombre), e.grupo_muscular]),
    );
    const edad = usuario?.fecha_nacimiento
      ? Math.floor(
          (ahora.getTime() - new Date(usuario.fecha_nacimiento).getTime()) /
            (365.25 * 24 * 60 * 60 * 1000),
        )
      : null;

    const series = new Map<MuscleId, number>();
    const residual = new Map<MuscleId, number>();
    const intensidadSuma = new Map<MuscleId, number>();
    const intensidadPeso = new Map<MuscleId, number>();
    const ultima = new Map<MuscleId, Date>();
    const porEjercicio = new Map<MuscleId, Map<string, number>>();
    const sinClasificar = new Set<string>();

    let seriesEstimadas = 0;
    let seriesTotales = 0;

    for (const sesion of sesiones) {
      const fecha = new Date(sesion.fecha_finalizacion ?? sesion.fecha_programada);
      const horas = Math.max(0, (ahora.getTime() - fecha.getTime()) / 3600000);

      const entradas = Array.isArray(sesion.ejercicios) ? sesion.ejercicios : [];
      const items = entradas
        .filter((e): e is Record<string, unknown> => !!e && typeof e === 'object')
        .map((e) => ({
          nombre: this.nombreEntrada(e),
          series: this.seriesEntrada(e),
          intensidad: this.intensidadEntrada(e),
          declara: this.declaraSeries(e),
        }));

      // Sin ejercicios utilizables queda el tipo de sesión, que ya reparte por
      // sí solo. Sin esta entrada de relleno, una sesión de Health Connect con
      // `ejercicios: []` desaparecería del mapa entera.
      if (!items.length) {
        items.push({ nombre: null, series: 1, intensidad: null, declara: false });
      }

      // Sesión sin series declaradas (cardio, o cualquiera cuyas entradas no
      // digan cuántas fueron): la duración es la única señal de cuánto trabajo
      // hubo, así que reparte el equivalente en series entre las entradas, en
      // vez de contar una sola por ejercicio nombrado. Una carrera de 50 min
      // contada como "1 serie de gemelos" es peor estimación que no contarla.
      const declaraSeries = items.some((i) => i.declara);
      const duracion = this.num(sesion.duracion_minutos);
      const estimada = !declaraSeries && duracion !== null && duracion > 0;
      if (estimada) {
        const equivalentes = Math.max(
          1,
          duracion / TrainingSessionService.MINUTOS_POR_SERIE_EQUIVALENTE,
        );
        const porItem = equivalentes / items.length;
        for (const item of items) item.series = porItem;
      }

      const intensidadSesion = this.intensidadPorFc(sesion, edad);

      for (const item of items) {
        const reparto = this.repartoEjercicio(
          item.nombre,
          sesion.tipo_entrenamiento,
          catalogo,
          sinClasificar,
        );
        const intensidad = item.intensidad ?? intensidadSesion;
        seriesTotales += item.series;
        if (estimada) seriesEstimadas += item.series;

        for (const [musculo, peso] of Object.entries(reparto) as [MuscleId, number][]) {
          const aporte = item.series * peso;
          series.set(musculo, (series.get(musculo) ?? 0) + aporte);

          residual.set(
            musculo,
            (residual.get(musculo) ?? 0) +
              aporte * Math.pow(2, -horas / VIDA_MEDIA_HORAS[musculo]),
          );

          if (intensidad !== null) {
            intensidadSuma.set(musculo, (intensidadSuma.get(musculo) ?? 0) + intensidad * aporte);
            intensidadPeso.set(musculo, (intensidadPeso.get(musculo) ?? 0) + aporte);
          }

          const anterior = ultima.get(musculo);
          if (!anterior || fecha > anterior) ultima.set(musculo, fecha);

          if (item.nombre) {
            const mapa = porEjercicio.get(musculo) ?? new Map<string, number>();
            mapa.set(item.nombre, (mapa.get(item.nombre) ?? 0) + aporte);
            porEjercicio.set(musculo, mapa);
          }
        }
      }
    }

    const musculos = IDS_MUSCULOS.map((id) => {
      const seriesRango = series.get(id) ?? 0;
      const seriesSemana = (seriesRango * 7) / ventana;
      const objetivo = SERIES_SEMANA[id];
      const pesoIntensidad = intensidadPeso.get(id) ?? 0;
      const fechaUltima = ultima.get(id) ?? null;

      // La fatiga se normaliza contra media semana de volumen máximo: si a un
      // músculo le queda "dentro" la mitad de todo lo que aguanta en una
      // semana, está a tope. Escalarla contra el residual máximo del propio
      // usuario dejaría siempre algún músculo en rojo, incluso descansado.
      const referenciaFatiga = objetivo.max / 2;

      return {
        id,
        nombre: MUSCULOS[id],
        series: Math.round(seriesRango * 10) / 10,
        series_semana: Math.round(seriesSemana * 10) / 10,
        objetivo,
        estado:
          seriesRango === 0
            ? 'sin_trabajo'
            : seriesSemana < objetivo.min
              ? 'bajo'
              : seriesSemana > objetivo.max
                ? 'alto'
                : 'en_rango',
        volumen: Math.round(Math.min(1, seriesSemana / objetivo.max) * 100) / 100,
        intensidad:
          pesoIntensidad > 0
            ? Math.round(((intensidadSuma.get(id) ?? 0) / pesoIntensidad) * 100) / 100
            : null,
        fatiga: Math.round(Math.min(1, (residual.get(id) ?? 0) / referenciaFatiga) * 100) / 100,
        horas_desde: fechaUltima
          ? Math.round((ahora.getTime() - fechaUltima.getTime()) / 3600000)
          : null,
        ultima_sesion: fechaUltima ? fechaUltima.toISOString() : null,
        ejercicios: [...(porEjercicio.get(id) ?? new Map<string, number>())]
          .sort((a, b) => b[1] - a[1])
          .slice(0, 4)
          .map(([nombre, aporte]) => ({ nombre, series: Math.round(aporte * 10) / 10 })),
      };
    });

    const volumenClasificado = [...series.values()].reduce((a, b) => a + b, 0);
    const volumenConEsfuerzo = [...intensidadPeso.values()].reduce((a, b) => a + b, 0);

    return {
      desde: desde.toISOString(),
      hasta: ahora.toISOString(),
      dias: ventana,
      sesiones: sesiones.length,
      series_totales: Math.round(seriesTotales * 10) / 10,
      /// Cuántas de esas series salen de convertir duración en vez de contarse.
      /// La tarjeta lo avisa cuando pesan: un mapa hecho solo de carreras no
      /// mide volumen de fuerza y no debería leerse como si lo hiciera.
      series_estimadas: Math.round(seriesEstimadas * 10) / 10,
      /// Fracción del volumen que llevaba señal de esfuerzo (RIR o FC). Sin
      /// esto la vista de intensidad miente por omisión: la media de las dos
      /// series que sí traían RIR se vería igual de sólida que la de treinta.
      cobertura_intensidad:
        volumenClasificado > 0
          ? Math.round((volumenConEsfuerzo / volumenClasificado) * 100) / 100
          : 0,
      /// Nombres que no casaron con ningún patrón ni con el catálogo, para
      /// saber qué falta en `muscle_map.ts` sin tener que adivinarlo.
      sin_clasificar: [...sinClasificar].slice(0, 10),
      musculos,
    };
  }

}
