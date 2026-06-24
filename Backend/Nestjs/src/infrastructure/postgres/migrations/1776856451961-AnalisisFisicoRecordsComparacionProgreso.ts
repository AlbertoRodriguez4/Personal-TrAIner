import { MigrationInterface, QueryRunner } from "typeorm";

export class AnalisisFisicoRecordsComparacionProgreso1776856451961 implements MigrationInterface {
    name = 'AnalisisFisicoRecordsComparacionProgreso1776856451961'

    public async up(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`ALTER TABLE "Analisis_Fisico_Records" ADD "comparacion_progreso" text`);
    }

    public async down(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`ALTER TABLE "Analisis_Fisico_Records" DROP COLUMN "comparacion_progreso"`);
    }
}
