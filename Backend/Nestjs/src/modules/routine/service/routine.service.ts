import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Routine } from '../entities/routine.entity';
import { RoutineDay } from '../entities/routine_day.entity';
import { Exercise } from '../entities/exercise.entity';
import {
  CreateExerciseDto,
  CreateRoutineDayDto,
  CreateRoutineDto,
} from '../dto/create-routine.dto';
import { UpdateRoutineDto } from '../dto/update-routine.dto';
import {
  AiRoutineDayDto,
  CreateRoutineFromAiDto,
} from '../dto/create-routine-from-ai.dto';
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

/// `day_of_week` tiene que ser un día real de la semana, escrito exactamente
/// así: la app Flutter lo cruza contra su lista fija (Lunes..Domingo) para
/// pintar el plan semanal. Cualquier otro valor —el viejo `Día N`— se guarda sin
/// error, pero la pantalla de edición sale vacía y al guardar se pierden los días.
const DIAS_SEMANA = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];

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

  /// Siempre por usuario: sin filtro, esto devolvía las rutinas de todos.
  async findAll(userId: string) {
    return this.routineRepository.find({
      where: { userId },
      relations: ['days', 'days.exercises'],
      order: { updated_at: 'DESC' },
    });
  }

  /// Un ejercicio nuevo con solo sus campos de datos, copiados uno a uno a
  /// propósito: pasarle a `create()` el objeto del cliente entero dejaba
  /// colarse un `id` (la app lo manda al reenviar una rutina que ya leyó), y
  /// con él `save()` actualizaba la fila de ese id —aunque fuera un ejercicio
  /// de la rutina de otro usuario— en vez de insertar una nueva.
  private nuevoEjercicio(ex: CreateExerciseDto): Exercise {
    return this.exerciseRepository.create({
      name: ex.name,
      sets: ex.sets,
      reps: ex.reps,
      weight: ex.weight,
      duration: ex.duration,
      notes: ex.notes,
    });
  }

  private nuevosDias(days: CreateRoutineDayDto[]): RoutineDay[] {
    return days.map((day) =>
      this.dayRepository.create({
        day_of_week: day.day_of_week,
        focus: day.focus,
        exercises: (day.exercises ?? []).map((ex) => this.nuevoEjercicio(ex)),
      }),
    );
  }

  /// Días de una rutina escrita por la IA, tanto al crearla como al
  /// sobrescribirla con `aplicar_cambios_rutina`: los dos caminos pasan por aquí
  /// para que ninguno vuelva a guardar el viejo `Día N` (ver DIAS_SEMANA). El
  /// fallback por índice cubre el caso de que la IA no mande `dia_semana`.
  private diasDesdeIa(dias: AiRoutineDayDto[]): RoutineDay[] {
    return (dias ?? []).map((day, index) =>
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
          }),
        ),
      }),
    );
  }

  async create(dto: CreateRoutineDto) {
    const routine = this.routineRepository.create({
      userId: dto.userId,
      name: dto.name,
      activity_type: dto.activity_type,
      description: dto.description,
      activa: true,
      days: this.nuevosDias(dto.days),
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
    if (dto.userId) {
      await this.routineRepository.update(
        { userId: dto.userId },
        { activa: false },
      );
    }

    const routine = this.routineRepository.create({
      userId: dto.userId,
      name: dto.nombre_rutina,
      activity_type: dto.tipo_entrenamiento,
      description: dto.notas_adicionales,
      activa: true,
      days: this.diasDesdeIa(dto.dias_entrenamiento),
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

      routine.days = this.nuevosDias(dto.days);
    }

    return this.routineRepository.save(routine);
  }

  async updateFromAiPayload(
    id: string,
    userId: string,
    dias_entrenamiento: AiRoutineDayDto[],
  ) {
    const routine = await this.findOneForUser(id, userId);

    if (routine.days && routine.days.length > 0) {
      await this.dayRepository.remove(routine.days);
    }

    routine.days = this.diasDesdeIa(dias_entrenamiento);

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
