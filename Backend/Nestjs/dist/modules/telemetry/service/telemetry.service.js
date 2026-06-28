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
exports.TelemetryService = void 0;
const common_1 = require("@nestjs/common");
const config_1 = require("@nestjs/config");
let TelemetryService = class TelemetryService {
    configService;
    constructor(configService) {
        this.configService = configService;
    }
    async analyzeHrSet(dto) {
        const baseUrl = this.configService.get('AI_PYTHON_URL') ?? 'http://127.0.0.1:8000';
        const path = this.configService.get('AI_PYTHON_SET_PATH') ?? '/ai/analyze-set';
        const endpoint = new URL(path, baseUrl).toString();
        const response = await fetch(endpoint, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                uid: dto.uid,
                eid: dto.eid,
                dur: dto.dur,
                hr: dto.hr,
            }),
        });
        if (!response.ok) {
            const errorBody = await response.text();
            throw new common_1.BadGatewayException(`Error al comunicarse con el servicio Python (${response.status}): ${errorBody}`);
        }
        const decoded = (await response.json());
        if (!this.isAiSetResponse(decoded)) {
            throw new common_1.BadGatewayException('La respuesta del servicio Python no tiene el formato esperado.');
        }
        return decoded;
    }
    isAiSetResponse(value) {
        if (!value || typeof value !== 'object')
            return false;
        const c = value;
        return (typeof c.rir_estimado === 'number' && typeof c.feedback === 'string');
    }
};
exports.TelemetryService = TelemetryService;
exports.TelemetryService = TelemetryService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [config_1.ConfigService])
], TelemetryService);
