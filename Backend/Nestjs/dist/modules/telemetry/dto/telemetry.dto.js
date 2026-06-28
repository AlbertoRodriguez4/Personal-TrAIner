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
exports.TelemetryDto = void 0;
const class_validator_1 = require("class-validator");
class TelemetryDto {
    uid;
    eid;
    dur;
    hr;
}
exports.TelemetryDto = TelemetryDto;
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.IsNotEmpty)({ message: 'uid obligatorio.' }),
    __metadata("design:type", String)
], TelemetryDto.prototype, "uid", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.IsNotEmpty)({ message: 'eid obligatorio.' }),
    __metadata("design:type", String)
], TelemetryDto.prototype, "eid", void 0);
__decorate([
    (0, class_validator_1.IsNumber)(),
    (0, class_validator_1.IsInt)(),
    (0, class_validator_1.IsNotEmpty)({ message: 'dur obligatorio.' }),
    __metadata("design:type", Number)
], TelemetryDto.prototype, "dur", void 0);
__decorate([
    (0, class_validator_1.IsArray)(),
    (0, class_validator_1.ArrayMinSize)(1, { message: 'hr no puede estar vacío.' }),
    (0, class_validator_1.IsInt)({ each: true }),
    __metadata("design:type", Array)
], TelemetryDto.prototype, "hr", void 0);
