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
exports.NutritionLog = void 0;
const typeorm_1 = require("typeorm");
let NutritionLog = class NutritionLog {
    id;
    userId;
    fecha_registro;
    calorias_consumidas;
    proteinas_g;
    carbohidratos_g;
    grasas_g;
    notas;
};
exports.NutritionLog = NutritionLog;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)('uuid'),
    __metadata("design:type", String)
], NutritionLog.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)('uuid', { name: 'user_id' }),
    __metadata("design:type", String)
], NutritionLog.prototype, "userId", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'date' }),
    __metadata("design:type", Date)
], NutritionLog.prototype, "fecha_registro", void 0);
__decorate([
    (0, typeorm_1.Column)('int'),
    __metadata("design:type", Number)
], NutritionLog.prototype, "calorias_consumidas", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'decimal', precision: 6, scale: 2 }),
    __metadata("design:type", Number)
], NutritionLog.prototype, "proteinas_g", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'decimal', precision: 6, scale: 2 }),
    __metadata("design:type", Number)
], NutritionLog.prototype, "carbohidratos_g", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'decimal', precision: 6, scale: 2 }),
    __metadata("design:type", Number)
], NutritionLog.prototype, "grasas_g", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'text', nullable: true }),
    __metadata("design:type", Object)
], NutritionLog.prototype, "notas", void 0);
exports.NutritionLog = NutritionLog = __decorate([
    (0, typeorm_1.Entity)('Registros_Nutricionales_Cualitativos')
], NutritionLog);
