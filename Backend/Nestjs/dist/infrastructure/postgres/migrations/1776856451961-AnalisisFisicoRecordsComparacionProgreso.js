"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.AnalisisFisicoRecordsComparacionProgreso1776856451961 = void 0;
class AnalisisFisicoRecordsComparacionProgreso1776856451961 {
    name = 'AnalisisFisicoRecordsComparacionProgreso1776856451961';
    async up(queryRunner) {
        await queryRunner.query(`ALTER TABLE "Analisis_Fisico_Records" ADD "comparacion_progreso" text`);
    }
    async down(queryRunner) {
        await queryRunner.query(`ALTER TABLE "Analisis_Fisico_Records" DROP COLUMN "comparacion_progreso"`);
    }
}
exports.AnalisisFisicoRecordsComparacionProgreso1776856451961 = AnalisisFisicoRecordsComparacionProgreso1776856451961;
