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
exports.NutritionLogController = void 0;
const common_1 = require("@nestjs/common");
const nutrition_log_service_1 = require("../service/nutrition_log.service");
const create_nutrition_log_dto_1 = require("../dto/create-nutrition-log.dto");
const update_nutrition_log_dto_1 = require("../dto/update-nutrition-log.dto");
const nutrition_log_query_dto_1 = require("../dto/nutrition-log-query.dto");
let NutritionLogController = class NutritionLogController {
    nutritionLogService;
    constructor(nutritionLogService) {
        this.nutritionLogService = nutritionLogService;
    }
    create(dto) {
        return this.nutritionLogService.create(dto);
    }
    findByUser(userId, query) {
        return this.nutritionLogService.findByUser(userId, query.startDate, query.endDate);
    }
    findToday(userId) {
        return this.nutritionLogService.findTodayByUser(userId);
    }
    findOne(id) {
        return this.nutritionLogService.findOne(id);
    }
    update(id, dto) {
        return this.nutritionLogService.update(id, dto);
    }
    remove(id) {
        return this.nutritionLogService.remove(id);
    }
};
exports.NutritionLogController = NutritionLogController;
__decorate([
    (0, common_1.Post)(),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [create_nutrition_log_dto_1.CreateNutritionLogDto]),
    __metadata("design:returntype", void 0)
], NutritionLogController.prototype, "create", null);
__decorate([
    (0, common_1.Get)('user/:userId'),
    __param(0, (0, common_1.Param)('userId')),
    __param(1, (0, common_1.Query)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, nutrition_log_query_dto_1.NutritionLogQueryDto]),
    __metadata("design:returntype", void 0)
], NutritionLogController.prototype, "findByUser", null);
__decorate([
    (0, common_1.Get)('user/:userId/today'),
    __param(0, (0, common_1.Param)('userId')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], NutritionLogController.prototype, "findToday", null);
__decorate([
    (0, common_1.Get)(':id'),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], NutritionLogController.prototype, "findOne", null);
__decorate([
    (0, common_1.Put)(':id'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, update_nutrition_log_dto_1.UpdateNutritionLogDto]),
    __metadata("design:returntype", void 0)
], NutritionLogController.prototype, "update", null);
__decorate([
    (0, common_1.Delete)(':id'),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], NutritionLogController.prototype, "remove", null);
exports.NutritionLogController = NutritionLogController = __decorate([
    (0, common_1.Controller)('nutrition-logs'),
    __metadata("design:paramtypes", [nutrition_log_service_1.NutritionLogService])
], NutritionLogController);
