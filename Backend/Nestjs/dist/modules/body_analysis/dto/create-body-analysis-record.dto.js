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
Object.defineProperty(exports, "__esModule", { value: true });
exports.CreateBodyAnalysisRecordDto = void 0;
const class_validator_1 = require("class-validator");
class CreateBodyAnalysisRecordDto {
    userId;
    fecha_analisis;
    analisis_general;
    peso_estimado_kg;
    porcentaje_grasa_estimado;
    masa_muscular_estimada_kg;
    somatotipo_estimado;
    nivel_fitness_estimado;
    puntos_fuertes_fisicos;
    areas_mejora_fisicas;
    recomendaciones;
    metricas_adicionales;
    notas_adicionales;
    comparacion_progreso;
}
exports.CreateBodyAnalysisRecordDto = CreateBodyAnalysisRecordDto;
__decorate([
    (0, class_validator_1.IsUUID)(),
    (0, class_validator_1.IsNotEmpty)(),
    __metadata("design:type", String)
], CreateBodyAnalysisRecordDto.prototype, "userId", void 0);
__decorate([
    (0, class_validator_1.IsDateString)(),
    (0, class_validator_1.IsOptional)(),
    __metadata("design:type", String)
], CreateBodyAnalysisRecordDto.prototype, "fecha_analisis", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.IsNotEmpty)(),
    __metadata("design:type", String)
], CreateBodyAnalysisRecordDto.prototype, "analisis_general", void 0);
__decorate([
    (0, class_validator_1.IsNumber)(),
    (0, class_validator_1.IsOptional)(),
    __metadata("design:type", Number)
], CreateBodyAnalysisRecordDto.prototype, "peso_estimado_kg", void 0);
__decorate([
    (0, class_validator_1.IsNumber)(),
    (0, class_validator_1.IsOptional)(),
    __metadata("design:type", Number)
], CreateBodyAnalysisRecordDto.prototype, "porcentaje_grasa_estimado", void 0);
__decorate([
    (0, class_validator_1.IsNumber)(),
    (0, class_validator_1.IsOptional)(),
    __metadata("design:type", Number)
], CreateBodyAnalysisRecordDto.prototype, "masa_muscular_estimada_kg", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.IsOptional)(),
    __metadata("design:type", String)
], CreateBodyAnalysisRecordDto.prototype, "somatotipo_estimado", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.IsOptional)(),
    __metadata("design:type", String)
], CreateBodyAnalysisRecordDto.prototype, "nivel_fitness_estimado", void 0);
__decorate([
    (0, class_validator_1.IsArray)(),
    (0, class_validator_1.IsOptional)(),
    __metadata("design:type", Array)
], CreateBodyAnalysisRecordDto.prototype, "puntos_fuertes_fisicos", void 0);
__decorate([
    (0, class_validator_1.IsArray)(),
    (0, class_validator_1.IsOptional)(),
    __metadata("design:type", Array)
], CreateBodyAnalysisRecordDto.prototype, "areas_mejora_fisicas", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.IsOptional)(),
    __metadata("design:type", String)
], CreateBodyAnalysisRecordDto.prototype, "recomendaciones", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    __metadata("design:type", Object)
], CreateBodyAnalysisRecordDto.prototype, "metricas_adicionales", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.IsOptional)(),
    __metadata("design:type", String)
], CreateBodyAnalysisRecordDto.prototype, "notas_adicionales", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.IsOptional)(),
    __metadata("design:type", String)
], CreateBodyAnalysisRecordDto.prototype, "comparacion_progreso", void 0);
