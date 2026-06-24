import { BadGatewayException, Injectable, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AnalyzeNutritionDto } from '../dto/analyze-nutrition.dto';
import { AnalyzeRoutineDto } from '../dto/analyze-routine.dto';
import { AnalyzeBodyDto } from '../dto/analyze-body.dto';
import { UserProfile } from '../../user_profile/entities/user_profile.entity';
import { CustomRoutine } from '../../custom_routine/entities/custom_routine.entity';
import { BodyAnalysisRecord } from '../../body_analysis/entities/body_analysis_record.entity';

type NutritionAiResponse = {
  calorias_consumidas: number;
  proteinas_g: number;
  carbohidratos_g: number;
  grasas_g: number;
  notas: string;
};

type RoutineAnalysisResponse = {
  analisis_general: string;
  puntos_fuertes: string[];
  areas_mejora: string[];
  propuesta_cambios: {
    descripcion: string;
    dias_modificados: {
      numero_dia: number;
      cambios: string[];
      ejercicios_sugeridos: {
        nombre: string;
        series: number;
        repeticiones: number;
        descanso_segundos: number;
        razon: string;
      }[];
    }[];
  } | null;
  recomendaciones_adicionales: string[];
  consulta_usuario_satisface: string;
};

type BodyAnalysisAiResponse = {
  analisis_general: string;
  peso_estimado_kg: number | null;
  porcentaje_grasa_estimado: number | null;
  masa_muscular_estimada_kg: number | null;
  somatotipo_estimado: string | null;
  nivel_fitness_estimado: string | null;
  puntos_fuertes_fisicos: string[];
  areas_mejora_fisicas: string[];
  recomendaciones: string;
  metricas_adicionales: Record<string, unknown> | null;
  notas_adicionales: string;
  comparacion_progreso: string | null;
};

@Injectable()
export class AiService {
  constructor(
    private readonly configService: ConfigService,
    @InjectRepository(UserProfile)
    private readonly profileRepository: Repository<UserProfile>,
    @InjectRepository(CustomRoutine)
    private readonly customRoutineRepository: Repository<CustomRoutine>,
    @InjectRepository(BodyAnalysisRecord)
    private readonly bodyAnalysisRepository: Repository<BodyAnalysisRecord>,
  ) {}

  async analyzeNutrition(payload: AnalyzeNutritionDto): Promise<NutritionAiResponse> {
    const baseUrl = this.configService.get<string>('AI_PYTHON_URL') ?? 'http://127.0.0.1:8000';
    const path = this.configService.get<string>('AI_PYTHON_NUTRITION_PATH') ?? '/api/ia/analizar-nutricion';
    const endpoint = new URL(path, baseUrl).toString();

    let userProfile: UserProfile | null = null;
    if (payload.user_id) {
      userProfile = await this.profileRepository.findOne({
        where: { user_id: payload.user_id },
      });
    }

    const response = await fetch(endpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        image_base64: payload.image_base64,
        prompt: payload.prompt,
        user_profile: userProfile ? this.serializeProfile(userProfile) : null,
      }),
    });

    if (!response.ok) {
      const errorBody = await response.text();
      throw new BadGatewayException(
        `Error al comunicarse con el servicio Python (${response.status}): ${errorBody}`,
      );
    }

    const decoded = (await response.json()) as unknown;
    if (!this.isNutritionAiResponse(decoded)) {
      throw new BadGatewayException(
        'La respuesta del servicio Python no tiene el formato esperado.',
      );
    }

    return decoded;
  }

  private serializeProfile(profile: UserProfile): Record<string, unknown> {
    return {
      dias_entrenamiento_semana: profile.dias_entrenamiento_semana,
      intensidad: profile.intensidad,
      nivel_experiencia: profile.nivel_experiencia,
      objetivos: profile.objetivos,
      tipo_cuerpo: profile.tipo_cuerpo,
      condiciones_medicas: profile.condiciones_medicas,
      bmi: profile.bmi,
      dexa_porcentaje_grasa: profile.dexa_porcentaje_grasa,
      dexa_masa_muscular_kg: profile.dexa_masa_muscular_kg,
      notas_adicionales: profile.notas_adicionales,
    };
  }

  private isNutritionAiResponse(value: unknown): value is NutritionAiResponse {
    if (!value || typeof value !== 'object') {
      return false;
    }

    const candidate = value as Partial<NutritionAiResponse>;
    return (
      typeof candidate.calorias_consumidas === 'number' &&
      typeof candidate.proteinas_g === 'number' &&
      typeof candidate.carbohidratos_g === 'number' &&
      typeof candidate.grasas_g === 'number' &&
      typeof candidate.notas === 'string'
    );
  }

  async analyzeRoutine(payload: AnalyzeRoutineDto): Promise<RoutineAnalysisResponse> {
    const baseUrl = this.configService.get<string>('AI_PYTHON_URL') ?? 'http://127.0.0.1:8000';
    const path = this.configService.get<string>('AI_PYTHON_ROUTINE_PATH') ?? '/api/ia/analizar-rutina';
    const endpoint = new URL(path, baseUrl).toString();

    let userProfile: UserProfile | null = null;
    let routine: CustomRoutine | null = null;

    if (payload.user_id) {
      userProfile = await this.profileRepository.findOne({
        where: { user_id: payload.user_id },
      });

      if (payload.routine_id) {
        routine = await this.customRoutineRepository.findOne({
          where: { id: payload.routine_id, userId: payload.user_id },
        });
        if (!routine) {
          throw new NotFoundException('Rutina no encontrada para este usuario.');
        }
      } else {
        routine = await this.customRoutineRepository.findOne({
          where: { userId: payload.user_id, activa: true },
        });
      }
    }

    if (!routine) {
      throw new NotFoundException('No se encontró ninguna rutina activa para analizar.');
    }

    const response = await fetch(endpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        prompt: payload.prompt ?? 'Analiza mi rutina de entrenamiento y dime si necesita mejoras.',
        user_profile: userProfile ? this.serializeProfile(userProfile) : null,
        routine: this.serializeRoutine(routine),
      }),
    });

    if (!response.ok) {
      const errorBody = await response.text();
      throw new BadGatewayException(
        `Error al comunicarse con el servicio Python (${response.status}): ${errorBody}`,
      );
    }

    const decoded = (await response.json()) as unknown;
    if (!this.isRoutineAnalysisResponse(decoded)) {
      throw new BadGatewayException(
        'La respuesta del servicio Python no tiene el formato esperado para análisis de rutina.',
      );
    }

    return decoded;
  }

  private serializeRoutine(routine: CustomRoutine): Record<string, unknown> {
    return {
      nombre_rutina: routine.nombre_rutina,
      tipo_entrenamiento: routine.tipo_entrenamiento,
      numero_dias: routine.numero_dias,
      dias_entrenamiento: routine.dias_entrenamiento,
      notas_adicionales: routine.notas_adicionales,
    };
  }

  private isRoutineAnalysisResponse(value: unknown): value is RoutineAnalysisResponse {
    if (!value || typeof value !== 'object') {
      return false;
    }

    const candidate = value as Partial<RoutineAnalysisResponse>;
    return (
      typeof candidate.analisis_general === 'string' &&
      Array.isArray(candidate.puntos_fuertes) &&
      Array.isArray(candidate.areas_mejora) &&
      (candidate.propuesta_cambios === null || typeof candidate.propuesta_cambios === 'object') &&
      Array.isArray(candidate.recomendaciones_adicionales) &&
      typeof candidate.consulta_usuario_satisface === 'string'
    );
  }

  async analyzeBody(payload: AnalyzeBodyDto): Promise<BodyAnalysisAiResponse & { registro_guardado: boolean; registro_tipo: 'nuevo' | 'actualizado' | 'ninguno'; historial_incluido: boolean }> {
    const baseUrl = this.configService.get<string>('AI_PYTHON_URL') ?? 'http://127.0.0.1:8000';
    const path = this.configService.get<string>('AI_PYTHON_BODY_PATH') ?? '/api/ia/analizar-fisico';
    const endpoint = new URL(path, baseUrl).toString();

    let userProfile: UserProfile | null = null;
    let bodyHistory: BodyAnalysisRecord[] = [];
    let shouldSaveNewRecord = false;

    if (payload.user_id) {
      userProfile = await this.profileRepository.findOne({
        where: { user_id: payload.user_id },
      });

      bodyHistory = await this.bodyAnalysisRepository.find({
        where: { userId: payload.user_id },
        order: { fecha_analisis: 'DESC' },
        take: 6,
      });

      const thirtyDaysAgo = new Date();
      thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

      const latestRecord = bodyHistory[0];
      shouldSaveNewRecord = !latestRecord || latestRecord.fecha_analisis < thirtyDaysAgo;
    }

    const response = await fetch(endpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        image_base64: payload.image_base64,
        prompt: payload.prompt,
        user_profile: userProfile ? this.serializeProfile(userProfile) : null,
        body_history: bodyHistory.length > 0 ? this.serializeBodyHistory(bodyHistory) : null,
      }),
    });

    if (!response.ok) {
      const errorBody = await response.text();
      throw new BadGatewayException(
        `Error al comunicarse con el servicio Python (${response.status}): ${errorBody}`,
      );
    }

    const decoded = (await response.json()) as unknown;
    if (!this.isBodyAnalysisAiResponse(decoded)) {
      throw new BadGatewayException(
        'La respuesta del servicio Python no tiene el formato esperado para análisis físico.',
      );
    }

    let registroGuardado = false;
    let registroTipo: 'nuevo' | 'actualizado' | 'ninguno' = 'ninguno';
    if (payload.user_id) {
      if (shouldSaveNewRecord) {
        await this.saveBodyAnalysisRecord(payload.user_id, decoded);
        registroGuardado = true;
        registroTipo = 'nuevo';
      } else if (bodyHistory.length > 0) {
        await this.updateLatestBodyAnalysisRecord(bodyHistory[0].id, decoded);
        registroGuardado = true;
        registroTipo = 'actualizado';
      }
    }

    return {
      ...decoded,
      registro_guardado: registroGuardado,
      registro_tipo: registroTipo,
      historial_incluido: bodyHistory.length > 0,
    };
  }

  private serializeBodyHistory(history: BodyAnalysisRecord[]): Record<string, unknown>[] {
    return history.map((record) => ({
      fecha_analisis: record.fecha_analisis.toISOString(),
      analisis_general: record.analisis_general,
      peso_estimado_kg: record.peso_estimado_kg,
      porcentaje_grasa_estimado: record.porcentaje_grasa_estimado,
      masa_muscular_estimada_kg: record.masa_muscular_estimada_kg,
      somatotipo_estimado: record.somatotipo_estimado,
      nivel_fitness_estimado: record.nivel_fitness_estimado,
      puntos_fuertes_fisicos: record.puntos_fuertes_fisicos,
      areas_mejora_fisicas: record.areas_mejora_fisicas,
      recomendaciones: record.recomendaciones,
      metricas_adicionales: record.metricas_adicionales,
      notas_adicionales: record.notas_adicionales,
      comparacion_progreso: record.comparacion_progreso,
    }));
  }

  private async saveBodyAnalysisRecord(userId: string, response: BodyAnalysisAiResponse): Promise<void> {
    const record = this.bodyAnalysisRepository.create({
      userId,
      fecha_analisis: new Date(),
      analisis_general: response.analisis_general,
      peso_estimado_kg: response.peso_estimado_kg ?? undefined,
      porcentaje_grasa_estimado: response.porcentaje_grasa_estimado ?? undefined,
      masa_muscular_estimada_kg: response.masa_muscular_estimada_kg ?? undefined,
      somatotipo_estimado: response.somatotipo_estimado ?? undefined,
      nivel_fitness_estimado: response.nivel_fitness_estimado ?? undefined,
      puntos_fuertes_fisicos: response.puntos_fuertes_fisicos ?? [],
      areas_mejora_fisicas: response.areas_mejora_fisicas ?? [],
      recomendaciones: response.recomendaciones,
      metricas_adicionales: response.metricas_adicionales ?? undefined,
      notas_adicionales: response.notas_adicionales,
      comparacion_progreso: response.comparacion_progreso ?? undefined,
    });
    await this.bodyAnalysisRepository.save(record);
  }

  private async updateLatestBodyAnalysisRecord(recordId: string, response: BodyAnalysisAiResponse): Promise<void> {
    const record = await this.bodyAnalysisRepository.findOne({ where: { id: recordId } });
    if (!record) {
      return;
    }
    record.analisis_general = response.analisis_general;
    record.peso_estimado_kg = response.peso_estimado_kg ?? undefined;
    record.porcentaje_grasa_estimado = response.porcentaje_grasa_estimado ?? undefined;
    record.masa_muscular_estimada_kg = response.masa_muscular_estimada_kg ?? undefined;
    record.somatotipo_estimado = response.somatotipo_estimado ?? undefined;
    record.nivel_fitness_estimado = response.nivel_fitness_estimado ?? undefined;
    record.puntos_fuertes_fisicos = response.puntos_fuertes_fisicos ?? [];
    record.areas_mejora_fisicas = response.areas_mejora_fisicas ?? [];
    record.recomendaciones = response.recomendaciones;
    record.metricas_adicionales = response.metricas_adicionales ?? undefined;
    record.notas_adicionales = response.notas_adicionales;
    record.comparacion_progreso = response.comparacion_progreso ?? undefined;
    record.fecha_analisis = new Date();
    await this.bodyAnalysisRepository.save(record);
  }

  private isBodyAnalysisAiResponse(value: unknown): value is BodyAnalysisAiResponse {
    if (!value || typeof value !== 'object') {
      return false;
    }

    const candidate = value as Partial<BodyAnalysisAiResponse>;
    return (
      typeof candidate.analisis_general === 'string' &&
      (candidate.peso_estimado_kg === null || typeof candidate.peso_estimado_kg === 'number') &&
      (candidate.porcentaje_grasa_estimado === null || typeof candidate.porcentaje_grasa_estimado === 'number') &&
      (candidate.masa_muscular_estimada_kg === null || typeof candidate.masa_muscular_estimada_kg === 'number') &&
      (candidate.somatotipo_estimado === null || typeof candidate.somatotipo_estimado === 'string') &&
      (candidate.nivel_fitness_estimado === null || typeof candidate.nivel_fitness_estimado === 'string') &&
      Array.isArray(candidate.puntos_fuertes_fisicos) &&
      Array.isArray(candidate.areas_mejora_fisicas) &&
      typeof candidate.recomendaciones === 'string' &&
      (candidate.metricas_adicionales === null || typeof candidate.metricas_adicionales === 'object') &&
      typeof candidate.notas_adicionales === 'string' &&
      (candidate.comparacion_progreso === null || typeof candidate.comparacion_progreso === 'string')
    );
  }
}
