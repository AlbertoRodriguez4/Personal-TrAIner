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
exports.CreateTrainingSessionDto = void 0;
const class_validator_1 = require("class-validator");
class CreateTrainingSessionDto {
    userId;
    fecha_programada;
    tipo_entrenamiento;
    ejercicios;
    estado;
}
exports.CreateTrainingSessionDto = CreateTrainingSessionDto;
__decorate([
    (0, class_validator_1.IsUUID)(),
    (0, class_validator_1.IsNotEmpty)(),
    __metadata("design:type", String)
], CreateTrainingSessionDto.prototype, "userId", void 0);
__decorate([
    (0, class_validator_1.IsDateString)(),
    (0, class_validator_1.IsNotEmpty)(),
    __metadata("design:type", String)
], CreateTrainingSessionDto.prototype, "fecha_programada", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.IsIn)(['fuerza', 'cardio', 'flexibilidad']),
    __metadata("design:type", String)
], CreateTrainingSessionDto.prototype, "tipo_entrenamiento", void 0);
__decorate([
    (0, class_validator_1.IsArray)(),
    (0, class_validator_1.ArrayNotEmpty)(),
    __metadata("design:type", Array)
], CreateTrainingSessionDto.prototype, "ejercicios", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.IsIn)(['pendiente', 'completado']),
    (0, class_validator_1.IsOptional)(),
    __metadata("design:type", String)
], CreateTrainingSessionDto.prototype, "estado", void 0);
