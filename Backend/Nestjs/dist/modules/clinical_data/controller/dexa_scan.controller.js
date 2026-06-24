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
exports.DexaScanController = void 0;
const common_1 = require("@nestjs/common");
const dexa_scan_service_1 = require("../service/dexa_scan.service");
const create_dexa_scan_dto_1 = require("../dto/create-dexa-scan.dto");
const update_dexa_scan_dto_1 = require("../dto/update-dexa-scan.dto");
let DexaScanController = class DexaScanController {
    dexaScanService;
    constructor(dexaScanService) {
        this.dexaScanService = dexaScanService;
    }
    create(dto) {
        return this.dexaScanService.create(dto);
    }
    findByUser(userId) {
        return this.dexaScanService.findByUser(userId);
    }
    findOne(id) {
        return this.dexaScanService.findOne(id);
    }
    update(id, dto) {
        return this.dexaScanService.update(id, dto);
    }
    remove(id) {
        return this.dexaScanService.remove(id);
    }
};
exports.DexaScanController = DexaScanController;
__decorate([
    (0, common_1.Post)(),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [create_dexa_scan_dto_1.CreateDexaScanDto]),
    __metadata("design:returntype", void 0)
], DexaScanController.prototype, "create", null);
__decorate([
    (0, common_1.Get)('user/:userId'),
    __param(0, (0, common_1.Param)('userId')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], DexaScanController.prototype, "findByUser", null);
__decorate([
    (0, common_1.Get)(':id'),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], DexaScanController.prototype, "findOne", null);
__decorate([
    (0, common_1.Put)(':id'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, update_dexa_scan_dto_1.UpdateDexaScanDto]),
    __metadata("design:returntype", void 0)
], DexaScanController.prototype, "update", null);
__decorate([
    (0, common_1.Delete)(':id'),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], DexaScanController.prototype, "remove", null);
exports.DexaScanController = DexaScanController = __decorate([
    (0, common_1.Controller)('dexa-scans'),
    __metadata("design:paramtypes", [dexa_scan_service_1.DexaScanService])
], DexaScanController);
