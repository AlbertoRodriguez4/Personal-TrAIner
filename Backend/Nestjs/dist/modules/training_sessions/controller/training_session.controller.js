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
exports.TrainingSessionController = void 0;
const common_1 = require("@nestjs/common");
const training_session_service_1 = require("../service/training_session.service");
const create_training_session_dto_1 = require("../dto/create-training-session.dto");
const update_training_session_dto_1 = require("../dto/update-training-session.dto");
let TrainingSessionController = class TrainingSessionController {
    trainingSessionService;
    constructor(trainingSessionService) {
        this.trainingSessionService = trainingSessionService;
    }
    create(dto) {
        return this.trainingSessionService.create(dto);
    }
    findByUser(userId) {
        return this.trainingSessionService.findByUser(userId);
    }
    findOne(id) {
        return this.trainingSessionService.findOne(id);
    }
    markAsCompleted(id) {
        return this.trainingSessionService.markAsCompleted(id);
    }
    update(id, dto) {
        return this.trainingSessionService.update(id, dto);
    }
    remove(id) {
        return this.trainingSessionService.remove(id);
    }
};
exports.TrainingSessionController = TrainingSessionController;
__decorate([
    (0, common_1.Post)(),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [create_training_session_dto_1.CreateTrainingSessionDto]),
    __metadata("design:returntype", void 0)
], TrainingSessionController.prototype, "create", null);
__decorate([
    (0, common_1.Get)('user/:userId'),
    __param(0, (0, common_1.Param)('userId')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], TrainingSessionController.prototype, "findByUser", null);
__decorate([
    (0, common_1.Get)(':id'),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], TrainingSessionController.prototype, "findOne", null);
__decorate([
    (0, common_1.Put)(':id/complete'),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], TrainingSessionController.prototype, "markAsCompleted", null);
__decorate([
    (0, common_1.Put)(':id'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, update_training_session_dto_1.UpdateTrainingSessionDto]),
    __metadata("design:returntype", void 0)
], TrainingSessionController.prototype, "update", null);
__decorate([
    (0, common_1.Delete)(':id'),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], TrainingSessionController.prototype, "remove", null);
exports.TrainingSessionController = TrainingSessionController = __decorate([
    (0, common_1.Controller)('training-sessions'),
    __metadata("design:paramtypes", [training_session_service_1.TrainingSessionService])
], TrainingSessionController);
