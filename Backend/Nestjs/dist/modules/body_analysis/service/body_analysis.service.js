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
exports.BodyAnalysisService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const body_analysis_record_entity_1 = require("../entities/body_analysis_record.entity");
let BodyAnalysisService = class BodyAnalysisService {
    bodyAnalysisRepository;
    constructor(bodyAnalysisRepository) {
        this.bodyAnalysisRepository = bodyAnalysisRepository;
    }
    async create(dto) {
        const entity = this.bodyAnalysisRepository.create({
            ...dto,
            fecha_analisis: dto.fecha_analisis ? new Date(dto.fecha_analisis) : new Date(),
        });
        return this.bodyAnalysisRepository.save(entity);
    }
    async findByUser(userId) {
        return this.bodyAnalysisRepository.find({
            where: { userId },
            order: { fecha_analisis: 'DESC' },
        });
    }
    async findLatestByUser(userId) {
        return this.bodyAnalysisRepository.findOne({
            where: { userId },
            order: { fecha_analisis: 'DESC' },
        });
    }
    async shouldCreateNewRecord(userId) {
        const latest = await this.findLatestByUser(userId);
        if (!latest) {
            return true;
        }
        const thirtyDaysAgo = new Date();
        thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
        return latest.fecha_analisis < thirtyDaysAgo;
    }
    async findHistoryForAiContext(userId, limit = 6) {
        return this.bodyAnalysisRepository.find({
            where: { userId },
            order: { fecha_analisis: 'DESC' },
            take: limit,
        });
    }
    async findOne(id) {
        const record = await this.bodyAnalysisRepository.findOne({ where: { id } });
        if (!record) {
            throw new common_1.NotFoundException('Registro de análisis físico no encontrado.');
        }
        return record;
    }
    async update(id, dto) {
        const record = await this.findOne(id);
        if (dto.userId !== undefined) {
            record.userId = dto.userId;
        }
        if (dto.fecha_analisis !== undefined) {
            record.fecha_analisis = new Date(dto.fecha_analisis);
        }
        if (dto.analisis_general !== undefined) {
            record.analisis_general = dto.analisis_general;
        }
        if (dto.peso_estimado_kg !== undefined) {
            record.peso_estimado_kg = dto.peso_estimado_kg;
        }
        if (dto.porcentaje_grasa_estimado !== undefined) {
            record.porcentaje_grasa_estimado = dto.porcentaje_grasa_estimado;
        }
        if (dto.masa_muscular_estimada_kg !== undefined) {
            record.masa_muscular_estimada_kg = dto.masa_muscular_estimada_kg;
        }
        if (dto.somatotipo_estimado !== undefined) {
            record.somatotipo_estimado = dto.somatotipo_estimado;
        }
        if (dto.nivel_fitness_estimado !== undefined) {
            record.nivel_fitness_estimado = dto.nivel_fitness_estimado;
        }
        if (dto.puntos_fuertes_fisicos !== undefined) {
            record.puntos_fuertes_fisicos = dto.puntos_fuertes_fisicos;
        }
        if (dto.areas_mejora_fisicas !== undefined) {
            record.areas_mejora_fisicas = dto.areas_mejora_fisicas;
        }
        if (dto.recomendaciones !== undefined) {
            record.recomendaciones = dto.recomendaciones;
        }
        if (dto.metricas_adicionales !== undefined) {
            record.metricas_adicionales = dto.metricas_adicionales;
        }
        if (dto.notas_adicionales !== undefined) {
            record.notas_adicionales = dto.notas_adicionales;
        }
        if (dto.comparacion_progreso !== undefined) {
            record.comparacion_progreso = dto.comparacion_progreso;
        }
        return this.bodyAnalysisRepository.save(record);
    }
    async remove(id) {
        const record = await this.findOne(id);
        await this.bodyAnalysisRepository.remove(record);
        return { message: 'Registro de análisis físico eliminado correctamente.' };
    }
};
exports.BodyAnalysisService = BodyAnalysisService;
exports.BodyAnalysisService = BodyAnalysisService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(body_analysis_record_entity_1.BodyAnalysisRecord)),
    __metadata("design:paramtypes", [typeorm_2.Repository])
], BodyAnalysisService);
