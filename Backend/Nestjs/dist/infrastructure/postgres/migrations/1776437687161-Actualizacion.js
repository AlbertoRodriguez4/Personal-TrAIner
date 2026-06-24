"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.Actualizacion1776437687161 = void 0;
class Actualizacion1776437687161 {
    name = 'Actualizacion1776437687161';
    async up(queryRunner) {
        await queryRunner.query(`ALTER TABLE "Usuarios" ALTER COLUMN "mapeo_identidad" DROP NOT NULL`);
    }
    async down(queryRunner) {
        await queryRunner.query(`ALTER TABLE "Usuarios" ALTER COLUMN "mapeo_identidad" SET NOT NULL`);
    }
}
exports.Actualizacion1776437687161 = Actualizacion1776437687161;
