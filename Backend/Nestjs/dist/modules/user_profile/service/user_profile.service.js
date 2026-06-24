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
exports.UserProfileService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const user_profile_entity_1 = require("../entities/user_profile.entity");
let UserProfileService = class UserProfileService {
    profileRepository;
    constructor(profileRepository) {
        this.profileRepository = profileRepository;
    }
    async create(dto) {
        const existing = await this.profileRepository.findOne({
            where: { user_id: dto.user_id },
        });
        if (existing) {
            return this.updateByUserId(dto.user_id, dto);
        }
        const profile = this.profileRepository.create(dto);
        return this.profileRepository.save(profile);
    }
    async findByUserId(userId) {
        return this.profileRepository.findOne({ where: { user_id: userId } });
    }
    async updateByUserId(userId, dto) {
        const profile = await this.findByUserId(userId);
        if (!profile) {
            throw new common_1.NotFoundException(`Perfil no encontrado para el usuario ${userId}`);
        }
        await this.profileRepository.update({ user_id: userId }, dto);
        return this.findByUserId(userId);
    }
    async removeByUserId(userId) {
        const profile = await this.findByUserId(userId);
        if (!profile) {
            throw new common_1.NotFoundException(`Perfil no encontrado para el usuario ${userId}`);
        }
        await this.profileRepository.remove(profile);
        return { message: 'Perfil eliminado correctamente' };
    }
};
exports.UserProfileService = UserProfileService;
exports.UserProfileService = UserProfileService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(user_profile_entity_1.UserProfile)),
    __metadata("design:paramtypes", [typeorm_2.Repository])
], UserProfileService);
