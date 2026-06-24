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
exports.DexaScanService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const dexa_scan_entity_1 = require("../entities/dexa_scan.entity");
let DexaScanService = class DexaScanService {
    dexaScanRepository;
    constructor(dexaScanRepository) {
        this.dexaScanRepository = dexaScanRepository;
    }
    async create(dto) {
        const entity = this.dexaScanRepository.create({
            ...dto,
            fecha_escaneo: new Date(dto.fecha_escaneo),
        });
        return this.dexaScanRepository.save(entity);
    }
    async findByUser(userId) {
        return this.dexaScanRepository.find({
            where: { userId },
            order: { fecha_escaneo: 'DESC' },
        });
    }
    async findOne(id) {
        const dexaScan = await this.dexaScanRepository.findOne({ where: { id } });
        if (!dexaScan) {
            throw new common_1.NotFoundException('Escáner DEXA no encontrado.');
        }
        return dexaScan;
    }
    async update(id, dto) {
        await this.findOne(id);
        await this.dexaScanRepository.update(id, {
            ...dto,
            fecha_escaneo: dto.fecha_escaneo ? new Date(dto.fecha_escaneo) : undefined,
        });
        return this.findOne(id);
    }
    async remove(id) {
        const dexaScan = await this.findOne(id);
        await this.dexaScanRepository.remove(dexaScan);
        return { message: 'Escáner DEXA eliminado correctamente.' };
    }
};
exports.DexaScanService = DexaScanService;
exports.DexaScanService = DexaScanService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(dexa_scan_entity_1.DexaScan)),
    __metadata("design:paramtypes", [typeorm_2.Repository])
], DexaScanService);
