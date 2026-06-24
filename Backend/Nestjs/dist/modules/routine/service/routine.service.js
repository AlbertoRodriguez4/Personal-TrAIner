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
exports.RoutineService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const routine_entity_1 = require("../entities/routine.entity");
const routine_day_entity_1 = require("../entities/routine_day.entity");
const exercise_entity_1 = require("../entities/exercise.entity");
let RoutineService = class RoutineService {
    routineRepository;
    dayRepository;
    exerciseRepository;
    constructor(routineRepository, dayRepository, exerciseRepository) {
        this.routineRepository = routineRepository;
        this.dayRepository = dayRepository;
        this.exerciseRepository = exerciseRepository;
    }
    async findAll() {
        return this.routineRepository.find({
            relations: ['days', 'days.exercises'],
            order: { updated_at: 'DESC' },
        });
    }
    async create(dto) {
        const routine = this.routineRepository.create({
            name: dto.name,
            activity_type: dto.activity_type,
            description: dto.description,
            days: dto.days.map((day) => this.dayRepository.create({
                day_of_week: day.day_of_week,
                focus: day.focus,
                exercises: day.exercises?.map((ex) => this.exerciseRepository.create(ex)) ?? [],
            })),
        });
        return this.routineRepository.save(routine);
    }
    async findOne(id) {
        const routine = await this.routineRepository.findOne({
            where: { id },
            relations: ['days', 'days.exercises'],
        });
        if (!routine) {
            throw new common_1.NotFoundException('Rutina no encontrada');
        }
        return routine;
    }
    async update(id, dto) {
        const routine = await this.findOne(id);
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
            routine.days = dto.days.map((day) => this.dayRepository.create({
                day_of_week: day.day_of_week,
                focus: day.focus,
                exercises: day.exercises?.map((ex) => this.exerciseRepository.create(ex)) ?? [],
            }));
        }
        return this.routineRepository.save(routine);
    }
    async remove(id) {
        const routine = await this.findOne(id);
        await this.routineRepository.remove(routine);
        return { message: 'Rutina eliminada correctamente' };
    }
};
exports.RoutineService = RoutineService;
exports.RoutineService = RoutineService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(routine_entity_1.Routine)),
    __param(1, (0, typeorm_1.InjectRepository)(routine_day_entity_1.RoutineDay)),
    __param(2, (0, typeorm_1.InjectRepository)(exercise_entity_1.Exercise)),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository])
], RoutineService);
