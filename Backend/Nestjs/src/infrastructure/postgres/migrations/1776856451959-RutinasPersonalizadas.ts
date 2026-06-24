import { MigrationInterface, QueryRunner } from "typeorm";

export class RutinasPersonalizadas1776856451959 implements MigrationInterface {
    name = 'RutinasPersonalizadas1776856451959'

    public async up(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`CREATE TABLE "Rutinas_Personalizadas" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "user_id" character varying NOT NULL, "nombre_rutina" character varying(100) NOT NULL, "tipo_entrenamiento" character varying(50) NOT NULL, "numero_dias" integer NOT NULL, "dias_entrenamiento" jsonb NOT NULL, "notas_adicionales" text, "activa" boolean NOT NULL DEFAULT false, "fecha_creacion" TIMESTAMP NOT NULL DEFAULT now(), "fecha_actualizacion" TIMESTAMP NOT NULL DEFAULT now(), CONSTRAINT "PK_RutinasPersonalizadas" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE INDEX "IDX_RutinasPersonalizadas_UserId" ON "Rutinas_Personalizadas" ("user_id")`);
        await queryRunner.query(`CREATE INDEX "IDX_RutinasPersonalizadas_Activa" ON "Rutinas_Personalizadas" ("activa")`);
    }

    public async down(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`DROP INDEX "IDX_RutinasPersonalizadas_Activa"`);
        await queryRunner.query(`DROP INDEX "IDX_RutinasPersonalizadas_UserId"`);
        await queryRunner.query(`DROP TABLE "Rutinas_Personalizadas"`);
    }
}
