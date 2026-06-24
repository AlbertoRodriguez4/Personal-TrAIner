"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.AiService = void 0;
const common_1 = require("@nestjs/common");
const config_1 = require("@nestjs/config");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const user_profile_entity_1 = require("../../user_profile/entities/user_profile.entity");
const custom_routine_entity_1 = require("../../custom_routine/entities/custom_routine.entity");
const body_analysis_record_entity_1 = require("../../body_analysis/entities/body_analysis_record.entity");
let AiService = class AiService {
    configService;
    profileRepository;
    customRoutineRepository;
    bodyAnalysisRepository;
    constructor(configService, profileRepository, customRoutineRepository, bodyAnalysisRepository) {
        this.configService = configService;
        this.profileRepository = profileRepository;
        this.customRoutineRepository = customRoutineRepository;
        this.bodyAnalysisRepository = bodyAnalysisRepository;
    }
    async analyzeNutrition(payload) {
        const baseUrl = this.configService.get('AI_PYTHON_URL') ?? 'http://127.0.0.1:8000';
        const path = this.configService.get('AI_PYTHON_NUTRITION_PATH') ?? '/api/ia/analizar-nutricion';
        const endpoint = new URL(path, baseUrl).toString();
        let userProfile = null;
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
            throw new common_1.BadGatewayException(`Error al comunicarse con el servicio Python (${response.status}): ${errorBody}`);
        }
        const decoded = (await response.json());
        if (!this.isNutritionAiResponse(decoded)) {
            throw new common_1.BadGatewayException('La respuesta del servicio Python no tiene el formato esperado.');
        }
        return decoded;
    }
    serializeProfile(profile) {
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
    isNutritionAiResponse(value) {
        if (!value || typeof value !== 'object') {
            return false;
        }
        const candidate = value;
        return (typeof candidate.calorias_consumidas === 'number' &&
            typeof candidate.proteinas_g === 'number' &&
            typeof candidate.carbohidratos_g === 'number' &&
            typeof candidate.grasas_g === 'number' &&
            typeof candidate.notas === 'string');
    }
    async analyzeRoutine(payload) {
        const baseUrl = this.configService.get('AI_PYTHON_URL') ?? 'http://127.0.0.1:8000';
        const path = this.configService.get('AI_PYTHON_ROUTINE_PATH') ?? '/api/ia/analizar-rutina';
        const endpoint = new URL(path, baseUrl).toString();
        let userProfile = null;
        let routine = null;
        if (payload.user_id) {
            userProfile = await this.profileRepository.findOne({
                where: { user_id: payload.user_id },
            });
            if (payload.routine_id) {
                routine = await this.customRoutineRepository.findOne({
                    where: { id: payload.routine_id, userId: payload.user_id },
                });
                if (!routine) {
                    throw new common_1.NotFoundException('Rutina no encontrada para este usuario.');
                }
            }
            else {
                routine = await this.customRoutineRepository.findOne({
                    where: { userId: payload.user_id, activa: true },
                });
            }
        }
        if (!routine) {
            throw new common_1.NotFoundException('No se encontró ninguna rutina activa para analizar.');
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
            throw new common_1.BadGatewayException(`Error al comunicarse con el servicio Python (${response.status}): ${errorBody}`);
        }
        const decoded = (await response.json());
        if (!this.isRoutineAnalysisResponse(decoded)) {
            throw new common_1.BadGatewayException('La respuesta del servicio Python no tiene el formato esperado para análisis de rutina.');
        }
        return decoded;
    }
    serializeRoutine(routine) {
        return {
            nombre_rutina: routine.nombre_rutina,
            tipo_entrenamiento: routine.tipo_entrenamiento,
            numero_dias: routine.numero_dias,
            dias_entrenamiento: routine.dias_entrenamiento,
            notas_adicionales: routine.notas_adicionales,
        };
    }
    isRoutineAnalysisResponse(value) {
        if (!value || typeof value !== 'object') {
            return false;
        }
        const candidate = value;
        return (typeof candidate.analisis_general === 'string' &&
            Array.isArray(candidate.puntos_fuertes) &&
            Array.isArray(candidate.areas_mejora) &&
            (candidate.propuesta_cambios === null || typeof candidate.propuesta_cambios === 'object') &&
            Array.isArray(candidate.recomendaciones_adicionales) &&
            typeof candidate.consulta_usuario_satisface === 'string');
    }
    async analyzeBody(payload) {
        const baseUrl = this.configService.get('AI_PYTHON_URL') ?? 'http://127.0.0.1:8000';
        const path = this.configService.get('AI_PYTHON_BODY_PATH') ?? '/api/ia/analizar-fisico';
        const endpoint = new URL(path, baseUrl).toString();
        let userProfile = null;
        let bodyHistory = [];
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
            throw new common_1.BadGatewayException(`Error al comunicarse con el servicio Python (${response.status}): ${errorBody}`);
        }
        const decoded = (await response.json());
        if (!this.isBodyAnalysisAiResponse(decoded)) {
            throw new common_1.BadGatewayException('La respuesta del servicio Python no tiene el formato esperado para análisis físico.');
        }
        let registroGuardado = false;
        let registroTipo = 'ninguno';
        if (payload.user_id) {
            if (shouldSaveNewRecord) {
                await this.saveBodyAnalysisRecord(payload.user_id, decoded);
                registroGuardado = true;
                registroTipo = 'nuevo';
            }
            else if (bodyHistory.length > 0) {
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
    serializeBodyHistory(history) {
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
    async saveBodyAnalysisRecord(userId, response) {
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
    async updateLatestBodyAnalysisRecord(recordId, response) {
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
    isBodyAnalysisAiResponse(value) {
        if (!value || typeof value !== 'object') {
            return false;
        }
        const candidate = value;
        return (typeof candidate.analisis_general === 'string' &&
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
            (candidate.comparacion_progreso === null || typeof candidate.comparacion_progreso === 'string'));
    }
};
exports.AiService = AiService;
exports.AiService = AiService = __decorate([
    (0, common_1.Injectable)(),
    __param(1, (0, typeorm_1.InjectRepository)(user_profile_entity_1.UserProfile)),
    __param(2, (0, typeorm_1.InjectRepository)(custom_routine_entity_1.CustomRoutine)),
    __param(3, (0, typeorm_1.InjectRepository)(body_analysis_record_entity_1.BodyAnalysisRecord)),
    __metadata("design:paramtypes", [config_1.ConfigService,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository])
], AiService);
