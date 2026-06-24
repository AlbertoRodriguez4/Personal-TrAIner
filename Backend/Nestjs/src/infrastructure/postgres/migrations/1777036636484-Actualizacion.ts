import { MigrationInterface, QueryRunner } from "typeorm";

export class Actualizacion1777036636484 implements MigrationInterface {
    name = 'Actualizacion1777036636484'

    public async up(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`CREATE TABLE "Rutinas_Personalizadas" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "user_id" character varying NOT NULL, "nombre_rutina" character varying(100) NOT NULL, "tipo_entrenamiento" character varying(50) NOT NULL, "numero_dias" integer NOT NULL, "dias_entrenamiento" jsonb NOT NULL, "notas_adicionales" text, "activa" boolean NOT NULL DEFAULT false, "fecha_creacion" TIMESTAMP NOT NULL DEFAULT now(), "fecha_actualizacion" TIMESTAMP NOT NULL DEFAULT now(), CONSTRAINT "PK_865cd9091ebd276d7147491cf69" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE TABLE "Analisis_Fisico_Records" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "user_id" character varying NOT NULL, "fecha_analisis" TIMESTAMP NOT NULL DEFAULT now(), "analisis_general" text NOT NULL, "peso_estimado_kg" numeric(5,2), "porcentaje_grasa_estimado" numeric(5,2), "masa_muscular_estimada_kg" numeric(5,2), "somatotipo_estimado" character varying(50), "nivel_fitness_estimado" character varying(50), "puntos_fuertes_fisicos" text, "areas_mejora_fisicas" text, "recomendaciones" text, "metricas_adicionales" jsonb, "notas_adicionales" text, "comparacion_progreso" text, CONSTRAINT "PK_5b371d4079de42be95b68ad560b" PRIMARY KEY ("id"))`);
    }

    public async down(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`DROP TABLE "Analisis_Fisico_Records"`);
        await queryRunner.query(`DROP TABLE "Rutinas_Personalizadas"`);
    }

}
