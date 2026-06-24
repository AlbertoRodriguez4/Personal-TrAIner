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
exports.TrainingSessionService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const training_session_entity_1 = require("../entities/training_session.entity");
let TrainingSessionService = class TrainingSessionService {
    trainingSessionRepository;
    constructor(trainingSessionRepository) {
        this.trainingSessionRepository = trainingSessionRepository;
    }
    async create(dto) {
        const entity = this.trainingSessionRepository.create({
            ...dto,
            fecha_programada: new Date(dto.fecha_programada),
            estado: dto.estado ?? 'pendiente',
        });
        return this.trainingSessionRepository.save(entity);
    }
    async findByUser(userId) {
        return this.trainingSessionRepository.find({
            where: { userId },
            order: { fecha_programada: 'DESC' },
        });
    }
    async findOne(id) {
        const trainingSession = await this.trainingSessionRepository.findOne({ where: { id } });
        if (!trainingSession) {
            throw new common_1.NotFoundException('Sesión de entrenamiento no encontrada.');
        }
        return trainingSession;
    }
    async markAsCompleted(id) {
        await this.findOne(id);
        await this.trainingSessionRepository.update(id, {
            estado: 'completado',
            fecha_finalizacion: new Date(),
        });
        return this.findOne(id);
    }
    async update(id, dto) {
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
        return this.trainingSessionRepository.save(trainingSession);
    }
    async remove(id) {
        const trainingSession = await this.findOne(id);
        await this.trainingSessionRepository.remove(trainingSession);
        return { message: 'Sesión de entrenamiento eliminada correctamente.' };
    }
};
exports.TrainingSessionService = TrainingSessionService;
exports.TrainingSessionService = TrainingSessionService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(training_session_entity_1.TrainingSession)),
    __metadata("design:paramtypes", [typeorm_2.Repository])
], TrainingSessionService);
