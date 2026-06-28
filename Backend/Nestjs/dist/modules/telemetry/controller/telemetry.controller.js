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
exports.TelemetryController = void 0;
const common_1 = require("@nestjs/common");
const telemetry_dto_1 = require("../dto/telemetry.dto");
const telemetry_service_1 = require("../service/telemetry.service");
let TelemetryController = class TelemetryController {
    telemetryService;
    constructor(telemetryService) {
        this.telemetryService = telemetryService;
    }
    analyzeHrSet(dto) {
        return this.telemetryService.analyzeHrSet(dto);
    }
};
exports.TelemetryController = TelemetryController;
__decorate([
    (0, common_1.Post)('hr-set'),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [telemetry_dto_1.TelemetryDto]),
    __metadata("design:returntype", void 0)
], TelemetryController.prototype, "analyzeHrSet", null);
exports.TelemetryController = TelemetryController = __decorate([
    (0, common_1.Controller)('telemetry'),
    __metadata("design:paramtypes", [telemetry_service_1.TelemetryService])
], TelemetryController);
