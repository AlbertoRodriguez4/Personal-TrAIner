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
exports.CustomRoutineService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const custom_routine_entity_1 = require("../entities/custom_routine.entity");
let CustomRoutineService = class CustomRoutineService {
    customRoutineRepository;
    constructor(customRoutineRepository) {
        this.customRoutineRepository = customRoutineRepository;
    }
    async create(dto) {
        const entity = this.customRoutineRepository.create({
            ...dto,
            activa: dto.activa ?? true,
        });
        return this.customRoutineRepository.save(entity);
    }
    async findByUser(userId) {
        return this.customRoutineRepository.find({
            where: { userId },
            order: { fecha_creacion: 'DESC' },
        });
    }
    async findActiveByUser(userId) {
        return this.customRoutineRepository.findOne({
            where: { userId, activa: true },
        });
    }
    async findOne(id) {
        const routine = await this.customRoutineRepository.findOne({ where: { id } });
        if (!routine) {
            throw new common_1.NotFoundException('Rutina personalizada no encontrada.');
        }
        return routine;
    }
    async update(id, dto) {
        const routine = await this.findOne(id);
        if (dto.userId !== undefined) {
            routine.userId = dto.userId;
        }
        if (dto.nombre_rutina !== undefined) {
            routine.nombre_rutina = dto.nombre_rutina;
        }
        if (dto.tipo_entrenamiento !== undefined) {
            routine.tipo_entrenamiento = dto.tipo_entrenamiento;
        }
        if (dto.numero_dias !== undefined) {
            routine.numero_dias = dto.numero_dias;
        }
        if (dto.dias_entrenamiento !== undefined) {
            routine.dias_entrenamiento = dto.dias_entrenamiento;
        }
        if (dto.notas_adicionales !== undefined) {
            routine.notas_adicionales = dto.notas_adicionales;
        }
        if (dto.activa !== undefined) {
            routine.activa = dto.activa;
        }
        return this.customRoutineRepository.save(routine);
    }
    async setAsActive(id, userId) {
        await this.customRoutineRepository.update({ userId }, { activa: false });
        const routine = await this.findOne(id);
        routine.activa = true;
        return this.customRoutineRepository.save(routine);
    }
    async remove(id) {
        const routine = await this.findOne(id);
        await this.customRoutineRepository.remove(routine);
        return { message: 'Rutina personalizada eliminada correctamente.' };
    }
};
exports.CustomRoutineService = CustomRoutineService;
exports.CustomRoutineService = CustomRoutineService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(custom_routine_entity_1.CustomRoutine)),
    __metadata("design:paramtypes", [typeorm_2.Repository])
], CustomRoutineService);
