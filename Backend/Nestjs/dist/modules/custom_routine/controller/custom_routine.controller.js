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
exports.CustomRoutineController = void 0;
const common_1 = require("@nestjs/common");
const custom_routine_service_1 = require("../service/custom_routine.service");
const create_custom_routine_dto_1 = require("../dto/create-custom-routine.dto");
const update_custom_routine_dto_1 = require("../dto/update-custom-routine.dto");
let CustomRoutineController = class CustomRoutineController {
    customRoutineService;
    constructor(customRoutineService) {
        this.customRoutineService = customRoutineService;
    }
    create(dto) {
        return this.customRoutineService.create(dto);
    }
    findByUser(userId) {
        return this.customRoutineService.findByUser(userId);
    }
    findActiveByUser(userId) {
        return this.customRoutineService.findActiveByUser(userId);
    }
    findOne(id) {
        return this.customRoutineService.findOne(id);
    }
    update(id, dto) {
        return this.customRoutineService.update(id, dto);
    }
    setAsActive(id, userId) {
        return this.customRoutineService.setAsActive(id, userId);
    }
    remove(id) {
        return this.customRoutineService.remove(id);
    }
};
exports.CustomRoutineController = CustomRoutineController;
__decorate([
    (0, common_1.Post)(),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [create_custom_routine_dto_1.CreateCustomRoutineDto]),
    __metadata("design:returntype", void 0)
], CustomRoutineController.prototype, "create", null);
__decorate([
    (0, common_1.Get)('user/:userId'),
    __param(0, (0, common_1.Param)('userId')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], CustomRoutineController.prototype, "findByUser", null);
__decorate([
    (0, common_1.Get)('user/:userId/active'),
    __param(0, (0, common_1.Param)('userId')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], CustomRoutineController.prototype, "findActiveByUser", null);
__decorate([
    (0, common_1.Get)(':id'),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], CustomRoutineController.prototype, "findOne", null);
__decorate([
    (0, common_1.Put)(':id'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, update_custom_routine_dto_1.UpdateCustomRoutineDto]),
    __metadata("design:returntype", void 0)
], CustomRoutineController.prototype, "update", null);
__decorate([
    (0, common_1.Put)(':id/activate'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)('userId')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String]),
    __metadata("design:returntype", void 0)
], CustomRoutineController.prototype, "setAsActive", null);
__decorate([
    (0, common_1.Delete)(':id'),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], CustomRoutineController.prototype, "remove", null);
exports.CustomRoutineController = CustomRoutineController = __decorate([
    (0, common_1.Controller)('custom-routines'),
    __metadata("design:paramtypes", [custom_routine_service_1.CustomRoutineService])
], CustomRoutineController);
