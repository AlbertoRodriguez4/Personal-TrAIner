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
exports.AiController = void 0;
const common_1 = require("@nestjs/common");
const analyze_nutrition_dto_1 = require("../dto/analyze-nutrition.dto");
const analyze_routine_dto_1 = require("../dto/analyze-routine.dto");
const analyze_body_dto_1 = require("../dto/analyze-body.dto");
const ai_service_1 = require("../service/ai.service");
let AiController = class AiController {
    aiService;
    constructor(aiService) {
        this.aiService = aiService;
    }
    analyzeNutrition(dto) {
        return this.aiService.analyzeNutrition(dto);
    }
    analyzeRoutine(dto) {
        return this.aiService.analyzeRoutine(dto);
    }
    analyzeBody(dto) {
        return this.aiService.analyzeBody(dto);
    }
};
exports.AiController = AiController;
__decorate([
    (0, common_1.Post)('analizar-nutricion'),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [analyze_nutrition_dto_1.AnalyzeNutritionDto]),
    __metadata("design:returntype", void 0)
], AiController.prototype, "analyzeNutrition", null);
__decorate([
    (0, common_1.Post)('analizar-rutina'),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [analyze_routine_dto_1.AnalyzeRoutineDto]),
    __metadata("design:returntype", void 0)
], AiController.prototype, "analyzeRoutine", null);
__decorate([
    (0, common_1.Post)('analizar-fisico'),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [analyze_body_dto_1.AnalyzeBodyDto]),
    __metadata("design:returntype", void 0)
], AiController.prototype, "analyzeBody", null);
exports.AiController = AiController = __decorate([
    (0, common_1.Controller)('ai'),
    __metadata("design:paramtypes", [ai_service_1.AiService])
], AiController);
