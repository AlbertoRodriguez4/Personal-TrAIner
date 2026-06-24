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
exports.PostureEvaluationService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const posture_evaluation_entity_1 = require("../entities/posture_evaluation.entity");
let PostureEvaluationService = class PostureEvaluationService {
    postureEvaluationRepository;
    constructor(postureEvaluationRepository) {
        this.postureEvaluationRepository = postureEvaluationRepository;
    }
    async create(dto) {
        const entity = this.postureEvaluationRepository.create({
            ...dto,
            fecha_evaluacion: new Date(dto.fecha_evaluacion),
            analisis_ia: this.normalizeAnalysis(dto.analisis_ia),
        });
        return this.postureEvaluationRepository.save(entity);
    }
    async findByUser(userId) {
        return this.postureEvaluationRepository.find({
            where: { userId },
            order: { fecha_evaluacion: 'DESC' },
        });
    }
    async findOne(id) {
        const evaluation = await this.postureEvaluationRepository.findOne({ where: { id } });
        if (!evaluation) {
            throw new common_1.NotFoundException('Evaluación postural no encontrada.');
        }
        return evaluation;
    }
    async update(id, dto) {
        await this.findOne(id);
        await this.postureEvaluationRepository.update(id, {
            ...dto,
            fecha_evaluacion: dto.fecha_evaluacion ? new Date(dto.fecha_evaluacion) : undefined,
            analisis_ia: dto.analisis_ia ? this.normalizeAnalysis(dto.analisis_ia) : undefined,
        });
        return this.findOne(id);
    }
    async remove(id) {
        const evaluation = await this.findOne(id);
        await this.postureEvaluationRepository.remove(evaluation);
        return { message: 'Evaluación postural eliminada correctamente.' };
    }
    normalizeAnalysis(analysis) {
        if (!analysis) {
            return '';
        }
        return typeof analysis === 'string' ? analysis : JSON.stringify(analysis);
    }
};
exports.PostureEvaluationService = PostureEvaluationService;
exports.PostureEvaluationService = PostureEvaluationService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(posture_evaluation_entity_1.PostureEvaluation)),
    __metadata("design:paramtypes", [typeorm_2.Repository])
], PostureEvaluationService);
