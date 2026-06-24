"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.AnalisisFisicoRecords1776856451960 = void 0;
class AnalisisFisicoRecords1776856451960 {
    name = 'AnalisisFisicoRecords1776856451960';
    async up(queryRunner) {
        await queryRunner.query(`CREATE TABLE "Analisis_Fisico_Records" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "user_id" character varying NOT NULL, "fecha_analisis" TIMESTAMP NOT NULL DEFAULT now(), "analisis_general" text NOT NULL, "peso_estimado_kg" numeric(5,2), "porcentaje_grasa_estimado" numeric(5,2), "masa_muscular_estimada_kg" numeric(5,2), "somatotipo_estimado" character varying(50), "nivel_fitness_estimado" character varying(50), "puntos_fuertes_fisicos" text, "areas_mejora_fisicas" text, "recomendaciones" text, "metricas_adicionales" jsonb, "notas_adicionales" text, CONSTRAINT "PK_AnalisisFisicoRecords" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE INDEX "IDX_AnalisisFisicoRecords_UserId" ON "Analisis_Fisico_Records" ("user_id")`);
        await queryRunner.query(`CREATE INDEX "IDX_AnalisisFisicoRecords_Fecha" ON "Analisis_Fisico_Records" ("fecha_analisis")`);
    }
    async down(queryRunner) {
        await queryRunner.query(`DROP INDEX "IDX_AnalisisFisicoRecords_Fecha"`);
        await queryRunner.query(`DROP INDEX "IDX_AnalisisFisicoRecords_UserId"`);
        await queryRunner.query(`DROP TABLE "Analisis_Fisico_Records"`);
    }
}
exports.AnalisisFisicoRecords1776856451960 = AnalisisFisicoRecords1776856451960;
