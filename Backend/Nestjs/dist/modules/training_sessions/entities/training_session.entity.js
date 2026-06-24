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
exports.TrainingSession = void 0;
const typeorm_1 = require("typeorm");
let TrainingSession = class TrainingSession {
    id;
    userId;
    fecha_programada;
    tipo_entrenamiento;
    ejercicios;
    estado;
    fecha_finalizacion;
};
exports.TrainingSession = TrainingSession;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)('uuid'),
    __metadata("design:type", String)
], TrainingSession.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)('uuid', { name: 'user_id' }),
    __metadata("design:type", String)
], TrainingSession.prototype, "userId", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'timestamp' }),
    __metadata("design:type", Date)
], TrainingSession.prototype, "fecha_programada", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'varchar', length: 50 }),
    __metadata("design:type", String)
], TrainingSession.prototype, "tipo_entrenamiento", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'jsonb' }),
    __metadata("design:type", Array)
], TrainingSession.prototype, "ejercicios", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'varchar', length: 30 }),
    __metadata("design:type", String)
], TrainingSession.prototype, "estado", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'timestamp', nullable: true }),
    __metadata("design:type", Object)
], TrainingSession.prototype, "fecha_finalizacion", void 0);
exports.TrainingSession = TrainingSession = __decorate([
    (0, typeorm_1.Entity)('Sesiones_Entrenamiento')
], TrainingSession);
