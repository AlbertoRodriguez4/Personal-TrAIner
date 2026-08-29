import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Routine } from '../entities/routine.entity';
import { RoutineDay } from '../entities/routine_day.entity';
import { Exercise } from '../entities/exercise.entity';
import { CreateRoutineDto } from '../dto/create-routine.dto';
import { UpdateRoutineDto } from '../dto/update-routine.dto';
import { CreateRoutineFromAiDto } from '../dto/create-routine-from-ai.dto';
import { ExerciseCatalog } from '../../exercises_catalog/entities/exercise_catalog.entity';
import {
  IDS_MUSCULOS,
  MUSCULOS,
  MuscleId,
  SERIES_POR_DEFECTO,
  SERIES_SEMANA,
  normalizar,
  repartoEjercicio,
} from '../../training_sessions/muscle_map';

@Injectable()
export class RoutineService {
  constructor(
    @InjectRepository(Routine)
    private readonly routineRepository: Repository<Routine>,
    @InjectRepository(RoutineDay)
    private readonly dayRepository: Repository<RoutineDay>,
    @InjectRepository(Exercise)
    private readonly exerciseRepository: Repository<Exercise>,
    @InjectRepository(ExerciseCatalog)
    private readonly exerciseCatalogRepository: Repository<ExerciseCatalog>,
  ) {}

  /// Nombre normalizado del catálogo → su miniatura, para rellenar la del
  /// ejercicio cuando quien escribe no la manda: la rutina que redacta la IA
  /// (que solo conoce nombres) y las creadas desde clientes viejos. Lo que sí
  /// venga en el payload gana, porque una rutina importada trae su propia
  /// imagen y puede referirse a un ejercicio que este catálogo no tiene.
  private async imagenesCatalogo(): Promise<Map<string, string>> {
    const filas = await this.exerciseCatalogRepository.find({
      select: ['nombre', 'imagen_url'],
    });
    const mapa = new Map<string, string>();
    for (const fila of filas) {
      if (fila.imagen_url) {
        mapa.set(normalizar(fila.nombre), fila.imagen_url);
      }
    }
    return mapa;
  }

  async findAll(userId?: string) {
    const whereCondition = userId ? { userId } : {};
    return this.routineRepository.find({
      where: whereCondition,
      relations: ['days', 'days.exercises'],
      order: { updated_at: 'DESC' },
    });
  }

  async create(dto: CreateRoutineDto) {
    const imagenes = await this.imagenesCatalogo();
    const routine = this.routineRepository.create({
      userId: dto.userId, // Esperamos que se pase en el DTO temporalmente o manualmente
      name: dto.name,
      activity_type: dto.activity_type,
      description: dto.description,
      activa: true,
      days: dto.days.map((day) =>
        this.dayRepository.create({
          day_of_week: day.day_of_week,
          focus: day.focus,
          exercises:
            day.exercises?.map((ex) =>
              this.exerciseRepository.create({
                ...ex,
                imagen_url: ex.imagen_url ?? imagenes.get(normalizar(ex.name)),
              }),
            ) ?? [],
        }),
      ),
    });

    if (dto.userId) {
      await this.routineRepository.update(
        { userId: dto.userId },
        { activa: false },
      );
    }

    return this.routineRepository.save(routine);
  }

  async createFromAiPayload(dto: CreateRoutineFromAiDto) {
    const imagenes = await this.imagenesCatalogo();

    if (dto.userId) {
      await this.routineRepository.update(
        { userId: dto.userId },
        { activa: false },
      );
    }

    // day_of_week tiene que ser un día real de la semana: la app Flutter lo cruza contra
    // su lista fija (Lunes..Domingo) para pintar el plan semanal. El viejo `Día N` no
    // casaba con ninguno, así que la rutina se guardaba pero la pantalla de edición
    // salía vacía y al guardar se perdían los días. El fallback por índice cubre el caso
    // de que la IA no mande dia_semana.
    const DIAS_SEMANA = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];

    const days = (dto.dias_entrenamiento ?? []).map((day, index) =>
      this.dayRepository.create({
        day_of_week:
          day.dia_semana && DIAS_SEMANA.includes(day.dia_semana)
            ? day.dia_semana
            : DIAS_SEMANA[index % 7],
        focus: `${day.nombre_dia} — ${day.grupo_muscular}`,
        exercises: (day.ejercicios ?? []).map((ex) =>
          this.exerciseRepository.create({
            name: ex.nombre,
            sets: ex.series,
            reps: String(ex.repeticiones),
            weight: ex.peso_sugerido_kg,
            rest_seconds: ex.descanso_segundos,
            notes: ex.notas,
            imagen_url: imagenes.get(normalizar(ex.nombre)),
          }),
        ),
      }),
    );

    const routine = this.routineRepository.create({
      userId: dto.userId,
      name: dto.nombre_rutina,
      activity_type: dto.tipo_entrenamiento,
      description: dto.notas_adicionales,
      activa: true,
      days,
    });

    return this.routineRepository.save(routine);
  }

  async findOne(id: string) {
    const routine = await this.routineRepository.findOne({
      where: { id },
      relations: ['days', 'days.exercises'],
    });
    if (!routine) {
      throw new NotFoundException('Rutina no encontrada');
    }
    return routine;
  }

  async findOneForUser(id: string, userId: string) {
    const routine = await this.findOne(id);
    if (routine.userId !== userId) {
      throw new NotFoundException('Rutina no encontrada');
    }
    return routine;
  }

  async findActiveByUser(userId: string) {
    return this.routineRepository.findOne({
      where: { userId, activa: true },
      relations: ['days', 'days.exercises'],
    });
  }

  async setAsActive(id: string, userId: string) {
    const routine = await this.findOneForUser(id, userId);
    await this.routineRepository.update(
      { userId },
      { activa: false },
    );
    routine.activa = true;
    return this.routineRepository.save(routine);
  }

  async update(id: string, userId: string, dto: UpdateRoutineDto) {
    const routine = await this.findOneForUser(id, userId);
    const imagenes = await this.imagenesCatalogo();

    if (dto.name !== undefined) {
      routine.name = dto.name;
    }
    if (dto.activity_type !== undefined) {
      routine.activity_type = dto.activity_type;
    }
    if (dto.description !== undefined) {
      routine.description = dto.description;
    }

    if (dto.days) {
      if (routine.days && routine.days.length > 0) {
        await this.dayRepository.remove(routine.days);
      }

      routine.days = dto.days.map((day) =>
        this.dayRepository.create({
          day_of_week: day.day_of_week,
          focus: day.focus,
          exercises:
            day.exercises?.map((ex) =>
              this.exerciseRepository.create({
                ...ex,
                imagen_url: ex.imagen_url ?? imagenes.get(normalizar(ex.name)),
              }),
            ) ?? [],
        }),
      );
    }

    return this.routineRepository.save(routine);
  }

  async updateFromAiPayload(id: string, userId: string, dias_entrenamiento: any[]) {
    const routine = await this.findOneForUser(id, userId);
    const imagenes = await this.imagenesCatalogo();

    if (routine.days && routine.days.length > 0) {
      await this.dayRepository.remove(routine.days);
    }

    routine.days = (dias_entrenamiento ?? []).map((day) =>
      this.dayRepository.create({
        day_of_week: `Día ${day.numero_dia}`,
        focus: `${day.nombre_dia} — ${day.grupo_muscular}`,
        exercises: (day.ejercicios ?? []).map((ex: any) =>
          this.exerciseRepository.create({
            name: ex.nombre,
            sets: ex.series,
            reps: String(ex.repeticiones),
            weight: ex.peso_sugerido_kg,
            rest_seconds: ex.descanso_segundos,
            notes: ex.notas,
            imagen_url: imagenes.get(normalizar(ex.nombre)),
          }),
        ),
      }),
    );

    return this.routineRepository.save(routine);
  }

  async remove(id: string, userId: string) {
    const routine = await this.findOneForUser(id, userId);
    await this.routineRepository.remove(routine);
    return { message: 'Rutina eliminada correctamente' };
  }

  /// Volumen semanal *planificado* por grupo muscular: la otra mitad del mapa
  /// muscular. `training-sessions/.../muscle-load` mide lo hecho y solo cuenta
  /// sesiones completadas a propósito; esto cuenta lo escrito en la rutina
  /// activa, y las dos cifras son comparables porque las dos son series por
  /// semana normalizadas contra el mismo `SERIES_SEMANA`.
  ///
  /// Sin intensidad ni fatiga: un plan no tiene esfuerzo ni recuperación, y
  /// devolverlas a cero las haría indistinguibles de "entrenó suave y está
  /// descansado".
  async getActiveMuscleLoad(userId: string) {
    const [rutina, catalogoFilas] = await Promise.all([
      this.findActiveByUser(userId),
      this.exerciseCatalogRepository.find(),
    ]);

    const vacia = {
      activa: false as const,
      routine_id: null,
      nombre: null,
      dias: 0,
      series_totales: 0,
      series_sin_declarar: 0,
      aviso_ciclo: null,
      sin_clasificar: [] as string[],
      musculos: [],
    };

    // `Routine.userId` es nullable (rutinas viejas sin migrar). `findActiveByUser`
    // ya filtra por userId, así que una rutina sin dueño no puede llegar aquí;
    // la comprobación deja escrito que si llegara no es de este usuario y no se
    // devuelve. Se responde el hueco vacío y no un 404 porque para la pantalla
    // es indistinguible de no tener rutina activa, y es un estado normal.
    if (!rutina || rutina.userId !== userId) return vacia;

    const catalogo = new Map(
      catalogoFilas.map((e) => [normalizar(e.nombre), e.grupo_muscular]),
    );

    const series = new Map<MuscleId, number>();
    const sinClasificar = new Set<string>();
    let seriesTotales = 0;
    let seriesSinDeclarar = 0;

    const dias = Array.isArray(rutina.days) ? rutina.days : [];

    // Se suman todos los días sin mirar `day_of_week`: el ciclo de una rutina
    // es semanal, así que el total de la rutina ya *es* el volumen semanal y
    // sale directamente comparable con el `series_semana` del endpoint real.
    for (const dia of dias) {
      const ejercicios = Array.isArray(dia?.exercises) ? dia.exercises : [];
      for (const ejercicio of ejercicios) {
        const nombre = ejercicio?.name ?? null;
        const declara = typeof ejercicio?.sets === 'number' && ejercicio.sets > 0;
        const cuantas = declara ? (ejercicio.sets as number) : SERIES_POR_DEFECTO;

        seriesTotales += cuantas;
        if (!declara) seriesSinDeclarar += cuantas;

        // `null` en el tipo de sesión: un ejercicio planificado no tiene de
        // dónde tirar si el nombre no casa, y repartirlo por defecto inventaría
        // volumen que el usuario no ha escrito. Va a `sin_clasificar`.
        const reparto = repartoEjercicio(nombre, null, catalogo, sinClasificar);
        if (!reparto) continue;

        for (const [musculo, peso] of Object.entries(reparto) as [MuscleId, number][]) {
          series.set(musculo, (series.get(musculo) ?? 0) + cuantas * peso);
        }
      }
    }

    const musculos = IDS_MUSCULOS.map((id) => {
      const seriesSemana = series.get(id) ?? 0;
      const objetivo = SERIES_SEMANA[id];
      return {
        id,
        nombre: MUSCULOS[id],
        series_semana: Math.round(seriesSemana * 10) / 10,
        objetivo,
        estado:
          seriesSemana === 0
            ? 'sin_trabajo'
            : seriesSemana < objetivo.min
              ? 'bajo'
              : seriesSemana > objetivo.max
                ? 'alto'
                : 'en_rango',
        volumen: Math.round(Math.min(1, seriesSemana / objetivo.max) * 100) / 100,
      };
    });

    return {
      activa: true as const,
      routine_id: rutina.id,
      nombre: rutina.name,
      dias: dias.length,
      series_totales: Math.round(seriesTotales * 10) / 10,
      /// Cuánto del total sale de suponer 3 series a un ejercicio que no las
      /// declara. La pantalla lo avisa cuando pesa: un plan hecho de defaults
      /// no mide la rutina, mide el default.
      series_sin_declarar: Math.round(seriesSinDeclarar * 10) / 10,
      /// Una rutina de más de 7 días no cumple un ciclo semanal, así que el
      /// total ya no son "series por semana". Se sigue sumando igual (es lo
      /// único que hay), pero la pantalla tiene que poder decirlo.
      aviso_ciclo:
        dias.length > 7
          ? `La rutina tiene ${dias.length} días, así que su ciclo no es semanal: ` +
            'las series por semana son una aproximación.'
          : null,
      sin_clasificar: [...sinClasificar].slice(0, 10),
      musculos,
    };
  }
}
