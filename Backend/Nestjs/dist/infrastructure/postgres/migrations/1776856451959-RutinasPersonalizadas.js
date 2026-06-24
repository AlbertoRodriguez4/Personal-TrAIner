"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.RutinasPersonalizadas1776856451959 = void 0;
class RutinasPersonalizadas1776856451959 {
    name = 'RutinasPersonalizadas1776856451959';
    async up(queryRunner) {
        await queryRunner.query(`CREATE TABLE "Rutinas_Personalizadas" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "user_id" character varying NOT NULL, "nombre_rutina" character varying(100) NOT NULL, "tipo_entrenamiento" character varying(50) NOT NULL, "numero_dias" integer NOT NULL, "dias_entrenamiento" jsonb NOT NULL, "notas_adicionales" text, "activa" boolean NOT NULL DEFAULT false, "fecha_creacion" TIMESTAMP NOT NULL DEFAULT now(), "fecha_actualizacion" TIMESTAMP NOT NULL DEFAULT now(), CONSTRAINT "PK_RutinasPersonalizadas" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE INDEX "IDX_RutinasPersonalizadas_UserId" ON "Rutinas_Personalizadas" ("user_id")`);
        await queryRunner.query(`CREATE INDEX "IDX_RutinasPersonalizadas_Activa" ON "Rutinas_Personalizadas" ("activa")`);
    }
    async down(queryRunner) {
        await queryRunner.query(`DROP INDEX "IDX_RutinasPersonalizadas_Activa"`);
        await queryRunner.query(`DROP INDEX "IDX_RutinasPersonalizadas_UserId"`);
        await queryRunner.query(`DROP TABLE "Rutinas_Personalizadas"`);
    }
}
exports.RutinasPersonalizadas1776856451959 = RutinasPersonalizadas1776856451959;
