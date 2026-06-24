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
exports.PostureEvaluation = void 0;
const typeorm_1 = require("typeorm");
let PostureEvaluation = class PostureEvaluation {
    id;
    userId;
    fecha_evaluacion;
    imagen_frontal_url;
    imagen_lateral_url;
    puntuacion_postura;
    analisis_ia;
};
exports.PostureEvaluation = PostureEvaluation;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)('uuid'),
    __metadata("design:type", String)
], PostureEvaluation.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)('uuid', { name: 'user_id' }),
    __metadata("design:type", String)
], PostureEvaluation.prototype, "userId", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'timestamp' }),
    __metadata("design:type", Date)
], PostureEvaluation.prototype, "fecha_evaluacion", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'text' }),
    __metadata("design:type", String)
], PostureEvaluation.prototype, "imagen_frontal_url", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'text' }),
    __metadata("design:type", String)
], PostureEvaluation.prototype, "imagen_lateral_url", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'decimal', precision: 5, scale: 2 }),
    __metadata("design:type", Number)
], PostureEvaluation.prototype, "puntuacion_postura", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'text' }),
    __metadata("design:type", String)
], PostureEvaluation.prototype, "analisis_ia", void 0);
exports.PostureEvaluation = PostureEvaluation = __decorate([
    (0, typeorm_1.Entity)('Evaluaciones_Posturales_Visuales')
], PostureEvaluation);
