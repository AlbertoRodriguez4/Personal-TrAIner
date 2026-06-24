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
exports.BodyAnalysisController = void 0;
const common_1 = require("@nestjs/common");
const body_analysis_service_1 = require("../service/body_analysis.service");
const create_body_analysis_record_dto_1 = require("../dto/create-body-analysis-record.dto");
const update_body_analysis_record_dto_1 = require("../dto/update-body-analysis-record.dto");
let BodyAnalysisController = class BodyAnalysisController {
    bodyAnalysisService;
    constructor(bodyAnalysisService) {
        this.bodyAnalysisService = bodyAnalysisService;
    }
    create(dto) {
        return this.bodyAnalysisService.create(dto);
    }
    findByUser(userId) {
        return this.bodyAnalysisService.findByUser(userId);
    }
    findLatestByUser(userId) {
        return this.bodyAnalysisService.findLatestByUser(userId);
    }
    shouldCreateNewRecord(userId) {
        return this.bodyAnalysisService.shouldCreateNewRecord(userId);
    }
    findOne(id) {
        return this.bodyAnalysisService.findOne(id);
    }
    update(id, dto) {
        return this.bodyAnalysisService.update(id, dto);
    }
    remove(id) {
        return this.bodyAnalysisService.remove(id);
    }
};
exports.BodyAnalysisController = BodyAnalysisController;
__decorate([
    (0, common_1.Post)(),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [create_body_analysis_record_dto_1.CreateBodyAnalysisRecordDto]),
    __metadata("design:returntype", void 0)
], BodyAnalysisController.prototype, "create", null);
__decorate([
    (0, common_1.Get)('user/:userId'),
    __param(0, (0, common_1.Param)('userId')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], BodyAnalysisController.prototype, "findByUser", null);
__decorate([
    (0, common_1.Get)('user/:userId/latest'),
    __param(0, (0, common_1.Param)('userId')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], BodyAnalysisController.prototype, "findLatestByUser", null);
__decorate([
    (0, common_1.Get)('user/:userId/should-create'),
    __param(0, (0, common_1.Param)('userId')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], BodyAnalysisController.prototype, "shouldCreateNewRecord", null);
__decorate([
    (0, common_1.Get)(':id'),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], BodyAnalysisController.prototype, "findOne", null);
__decorate([
    (0, common_1.Put)(':id'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, update_body_analysis_record_dto_1.UpdateBodyAnalysisRecordDto]),
    __metadata("design:returntype", void 0)
], BodyAnalysisController.prototype, "update", null);
__decorate([
    (0, common_1.Delete)(':id'),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], BodyAnalysisController.prototype, "remove", null);
exports.BodyAnalysisController = BodyAnalysisController = __decorate([
    (0, common_1.Controller)('body-analysis'),
    __metadata("design:paramtypes", [body_analysis_service_1.BodyAnalysisService])
], BodyAnalysisController);
