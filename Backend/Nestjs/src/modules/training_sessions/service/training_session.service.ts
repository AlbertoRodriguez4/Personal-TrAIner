import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { TrainingSession } from '../entities/training_session.entity';
import { CreateTrainingSessionDto } from '../dto/create-training-session.dto';
import { UpdateTrainingSessionDto } from '../dto/update-training-session.dto';

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
}
