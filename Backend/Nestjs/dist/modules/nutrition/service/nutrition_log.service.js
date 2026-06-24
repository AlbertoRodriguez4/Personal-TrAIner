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
exports.NutritionLogService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const nutrition_log_entity_1 = require("../entities/nutrition_log.entity");
let NutritionLogService = class NutritionLogService {
    nutritionLogRepository;
    constructor(nutritionLogRepository) {
        this.nutritionLogRepository = nutritionLogRepository;
    }
    async create(dto) {
        const entity = this.nutritionLogRepository.create({
            ...dto,
            fecha_registro: new Date(dto.fecha_registro),
        });
        return this.nutritionLogRepository.save(entity);
    }
    async findByUser(userId, startDate, endDate) {
        if (startDate && endDate) {
            return this.nutritionLogRepository.find({
                where: {
                    userId,
                    fecha_registro: (0, typeorm_2.Between)(new Date(startDate), new Date(endDate)),
                },
                order: { fecha_registro: 'DESC' },
            });
        }
        if (startDate) {
            return this.nutritionLogRepository.find({
                where: {
                    userId,
                    fecha_registro: (0, typeorm_2.MoreThanOrEqual)(new Date(startDate)),
                },
                order: { fecha_registro: 'DESC' },
            });
        }
        if (endDate) {
            return this.nutritionLogRepository.find({
                where: {
                    userId,
                    fecha_registro: (0, typeorm_2.LessThanOrEqual)(new Date(endDate)),
                },
                order: { fecha_registro: 'DESC' },
            });
        }
        return this.nutritionLogRepository.find({
            where: { userId },
            order: { fecha_registro: 'DESC' },
        });
    }
    async findTodayByUser(userId) {
        const start = new Date();
        start.setHours(0, 0, 0, 0);
        const end = new Date(start);
        end.setDate(end.getDate() + 1);
        return this.nutritionLogRepository.findOne({
            where: {
                userId,
                fecha_registro: (0, typeorm_2.Between)(start, end),
            },
            order: { fecha_registro: 'DESC' },
        });
    }
    async findOne(id) {
        const nutritionLog = await this.nutritionLogRepository.findOne({ where: { id } });
        if (!nutritionLog) {
            throw new common_1.NotFoundException('Registro nutricional no encontrado.');
        }
        return nutritionLog;
    }
    async update(id, dto) {
        await this.findOne(id);
        await this.nutritionLogRepository.update(id, {
            ...dto,
            fecha_registro: dto.fecha_registro ? new Date(dto.fecha_registro) : undefined,
        });
        return this.findOne(id);
    }
    async remove(id) {
        const nutritionLog = await this.findOne(id);
        await this.nutritionLogRepository.remove(nutritionLog);
        return { message: 'Registro nutricional eliminado correctamente.' };
    }
};
exports.NutritionLogService = NutritionLogService;
exports.NutritionLogService = NutritionLogService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(nutrition_log_entity_1.NutritionLog)),
    __metadata("design:paramtypes", [typeorm_2.Repository])
], NutritionLogService);
