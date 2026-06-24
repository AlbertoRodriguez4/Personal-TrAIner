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
exports.BodyAnalysisRecord = void 0;
const typeorm_1 = require("typeorm");
let BodyAnalysisRecord = class BodyAnalysisRecord {
    id;
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
};
exports.BodyAnalysisRecord = BodyAnalysisRecord;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)('uuid'),
    __metadata("design:type", String)
], BodyAnalysisRecord.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'user_id' }),
    __metadata("design:type", String)
], BodyAnalysisRecord.prototype, "userId", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'timestamp', default: () => 'CURRENT_TIMESTAMP' }),
    __metadata("design:type", Date)
], BodyAnalysisRecord.prototype, "fecha_analisis", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'text' }),
    __metadata("design:type", String)
], BodyAnalysisRecord.prototype, "analisis_general", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'decimal', precision: 5, scale: 2, nullable: true }),
    __metadata("design:type", Number)
], BodyAnalysisRecord.prototype, "peso_estimado_kg", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'decimal', precision: 5, scale: 2, nullable: true }),
    __metadata("design:type", Number)
], BodyAnalysisRecord.prototype, "porcentaje_grasa_estimado", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'decimal', precision: 5, scale: 2, nullable: true }),
    __metadata("design:type", Number)
], BodyAnalysisRecord.prototype, "masa_muscular_estimada_kg", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'varchar', length: 50, nullable: true }),
    __metadata("design:type", String)
], BodyAnalysisRecord.prototype, "somatotipo_estimado", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'varchar', length: 50, nullable: true }),
    __metadata("design:type", String)
], BodyAnalysisRecord.prototype, "nivel_fitness_estimado", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'simple-array', nullable: true }),
    __metadata("design:type", Array)
], BodyAnalysisRecord.prototype, "puntos_fuertes_fisicos", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'simple-array', nullable: true }),
    __metadata("design:type", Array)
], BodyAnalysisRecord.prototype, "areas_mejora_fisicas", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'text', nullable: true }),
    __metadata("design:type", String)
], BodyAnalysisRecord.prototype, "recomendaciones", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'jsonb', nullable: true }),
    __metadata("design:type", Object)
], BodyAnalysisRecord.prototype, "metricas_adicionales", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'text', nullable: true }),
    __metadata("design:type", String)
], BodyAnalysisRecord.prototype, "notas_adicionales", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'text', nullable: true }),
    __metadata("design:type", String)
], BodyAnalysisRecord.prototype, "comparacion_progreso", void 0);
exports.BodyAnalysisRecord = BodyAnalysisRecord = __decorate([
    (0, typeorm_1.Entity)('Analisis_Fisico_Records')
], BodyAnalysisRecord);
