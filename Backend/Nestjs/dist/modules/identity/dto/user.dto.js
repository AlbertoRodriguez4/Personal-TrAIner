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
exports.UserDto = void 0;
const class_validator_1 = require("class-validator");
class UserDto {
    nombre_completo;
    email;
    // --- NUEVO CAMPO: CONTRASEÑA ---
    password;
    fecha_nacimiento;
    estatura_base_cm;
    peso_base_kg;
    // --- CAMBIO: AHORA ES OPCIONAL ---
    // Si el usuario se registra con email/password, esto puede venir vacío. 
    // Solo se llenará si decide iniciar sesión con Google/Apple.
    mapeo_identidad;
}
exports.UserDto = UserDto;
__decorate([
    (0, class_validator_1.IsString)({ message: 'El nombre debe ser una cadena de texto válida' }),
    (0, class_validator_1.IsNotEmpty)({ message: 'El nombre completo es obligatorio' }),
    __metadata("design:type", String)
], UserDto.prototype, "nombre_completo", void 0);
__decorate([
    (0, class_validator_1.IsEmail)({}, { message: 'El formato del correo electrónico es inválido' }),
    (0, class_validator_1.IsNotEmpty)({ message: 'El correo electrónico es obligatorio' }),
    __metadata("design:type", String)
], UserDto.prototype, "email", void 0);
__decorate([
    (0, class_validator_1.IsString)({ message: 'La contraseña debe ser una cadena de texto' }),
    (0, class_validator_1.IsNotEmpty)({ message: 'La contraseña es obligatoria' }),
    (0, class_validator_1.MinLength)(6, { message: 'La contraseña debe tener al menos 6 caracteres' }),
    __metadata("design:type", String)
], UserDto.prototype, "password", void 0);
__decorate([
    (0, class_validator_1.IsDateString)({}, { message: 'La fecha de nacimiento debe ser una fecha válida (YYYY-MM-DD)' }),
    (0, class_validator_1.IsNotEmpty)({ message: 'La fecha de nacimiento es obligatoria' }),
    __metadata("design:type", String)
], UserDto.prototype, "fecha_nacimiento", void 0);
__decorate([
    (0, class_validator_1.IsNumber)({}, { message: 'La estatura debe ser un número' }),
    (0, class_validator_1.Min)(50, { message: 'La estatura base debe ser de al menos 50 cm' }),
    (0, class_validator_1.Max)(300, { message: 'La estatura base ingresada excede el límite permitido' }),
    (0, class_validator_1.IsNotEmpty)({ message: 'La estatura es obligatoria para los cálculos biométricos' }),
    __metadata("design:type", Number)
], UserDto.prototype, "estatura_base_cm", void 0);
__decorate([
    (0, class_validator_1.IsNumber)({}, { message: 'El peso debe ser un número' }),
    (0, class_validator_1.Min)(20, { message: 'El peso base debe ser de al menos 20 kg' }),
    (0, class_validator_1.Max)(500, { message: 'El peso base ingresado excede el límite permitido' }),
    (0, class_validator_1.IsNotEmpty)({ message: 'El peso es obligatorio para los cálculos biométricos' }),
    __metadata("design:type", Number)
], UserDto.prototype, "peso_base_kg", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)({ message: 'El mapeo de identidad debe ser un texto válido' }),
    __metadata("design:type", String)
], UserDto.prototype, "mapeo_identidad", void 0);
