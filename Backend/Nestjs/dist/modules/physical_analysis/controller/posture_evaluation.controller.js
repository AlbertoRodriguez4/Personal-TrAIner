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
exports.PostureEvaluationController = void 0;
const common_1 = require("@nestjs/common");
const posture_evaluation_service_1 = require("../service/posture_evaluation.service");
const create_posture_evaluation_dto_1 = require("../dto/create-posture-evaluation.dto");
const update_posture_evaluation_dto_1 = require("../dto/update-posture-evaluation.dto");
let PostureEvaluationController = class PostureEvaluationController {
    postureEvaluationService;
    constructor(postureEvaluationService) {
        this.postureEvaluationService = postureEvaluationService;
    }
    create(dto) {
        return this.postureEvaluationService.create(dto);
    }
    findByUser(userId) {
        return this.postureEvaluationService.findByUser(userId);
    }
    findOne(id) {
        return this.postureEvaluationService.findOne(id);
    }
    update(id, dto) {
        return this.postureEvaluationService.update(id, dto);
    }
    remove(id) {
        return this.postureEvaluationService.remove(id);
    }
};
exports.PostureEvaluationController = PostureEvaluationController;
__decorate([
    (0, common_1.Post)(),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [create_posture_evaluation_dto_1.CreatePostureEvaluationDto]),
    __metadata("design:returntype", void 0)
], PostureEvaluationController.prototype, "create", null);
__decorate([
    (0, common_1.Get)('user/:userId'),
    __param(0, (0, common_1.Param)('userId')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], PostureEvaluationController.prototype, "findByUser", null);
__decorate([
    (0, common_1.Get)(':id'),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], PostureEvaluationController.prototype, "findOne", null);
__decorate([
    (0, common_1.Put)(':id'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, update_posture_evaluation_dto_1.UpdatePostureEvaluationDto]),
    __metadata("design:returntype", void 0)
], PostureEvaluationController.prototype, "update", null);
__decorate([
    (0, common_1.Delete)(':id'),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], PostureEvaluationController.prototype, "remove", null);
exports.PostureEvaluationController = PostureEvaluationController = __decorate([
    (0, common_1.Controller)('posture-evaluations'),
    __metadata("design:paramtypes", [posture_evaluation_service_1.PostureEvaluationService])
], PostureEvaluationController);
