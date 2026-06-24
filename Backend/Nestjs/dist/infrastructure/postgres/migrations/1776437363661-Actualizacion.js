"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.Actualizacion1776437363661 = void 0;
class Actualizacion1776437363661 {
    name = 'Actualizacion1776437363661';
    async up(queryRunner) {
        await queryRunner.query(`ALTER TABLE "Usuarios" ADD "password" character varying NOT NULL`);
    }
    async down(queryRunner) {
        await queryRunner.query(`ALTER TABLE "Usuarios" DROP COLUMN "password"`);
    }
}
exports.Actualizacion1776437363661 = Actualizacion1776437363661;
