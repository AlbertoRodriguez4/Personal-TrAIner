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
exports.UserProfileController = void 0;
const common_1 = require("@nestjs/common");
const user_profile_service_1 = require("../service/user_profile.service");
const create_user_profile_dto_1 = require("../dto/create-user-profile.dto");
const update_user_profile_dto_1 = require("../dto/update-user-profile.dto");
let UserProfileController = class UserProfileController {
    profileService;
    constructor(profileService) {
        this.profileService = profileService;
    }
    create(dto) {
        return this.profileService.create(dto);
    }
    findByUserId(userId) {
        return this.profileService.findByUserId(userId);
    }
    updateByUserId(userId, dto) {
        return this.profileService.updateByUserId(userId, dto);
    }
    removeByUserId(userId) {
        return this.profileService.removeByUserId(userId);
    }
};
exports.UserProfileController = UserProfileController;
__decorate([
    (0, common_1.Post)(),
    (0, common_1.HttpCode)(common_1.HttpStatus.CREATED),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [create_user_profile_dto_1.CreateUserProfileDto]),
    __metadata("design:returntype", void 0)
], UserProfileController.prototype, "create", null);
__decorate([
    (0, common_1.Get)('user/:userId'),
    __param(0, (0, common_1.Param)('userId')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], UserProfileController.prototype, "findByUserId", null);
__decorate([
    (0, common_1.Put)('user/:userId'),
    __param(0, (0, common_1.Param)('userId')),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, update_user_profile_dto_1.UpdateUserProfileDto]),
    __metadata("design:returntype", void 0)
], UserProfileController.prototype, "updateByUserId", null);
__decorate([
    (0, common_1.Delete)('user/:userId'),
    __param(0, (0, common_1.Param)('userId')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], UserProfileController.prototype, "removeByUserId", null);
exports.UserProfileController = UserProfileController = __decorate([
    (0, common_1.Controller)('user-profiles'),
    __metadata("design:paramtypes", [user_profile_service_1.UserProfileService])
], UserProfileController);
