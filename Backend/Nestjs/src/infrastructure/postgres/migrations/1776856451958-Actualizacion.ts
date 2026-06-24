import { MigrationInterface, QueryRunner } from "typeorm";

export class Actualizacion1776856451958 implements MigrationInterface {
    name = 'Actualizacion1776856451958'

    public async up(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`CREATE TABLE "Perfiles_Usuario" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "user_id" character varying NOT NULL, "dias_entrenamiento_semana" integer, "intensidad" character varying(50), "nivel_experiencia" character varying(50), "objetivos" text, "tipo_cuerpo" character varying(50), "condiciones_medicas" text, "bmi" numeric(5,2), "dexa_porcentaje_grasa" numeric(5,2), "dexa_masa_muscular_kg" numeric(6,2), "notas_adicionales" text, "fecha_creacion" TIMESTAMP NOT NULL DEFAULT now(), "fecha_actualizacion" TIMESTAMP NOT NULL DEFAULT now(), CONSTRAINT "UQ_a397f12a6022cf9c8fc89fb1833" UNIQUE ("user_id"), CONSTRAINT "PK_239dc282a3695505ae621ebf7b9" PRIMARY KEY ("id"))`);
    }

    public async down(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`DROP TABLE "Perfiles_Usuario"`);
    }

}
