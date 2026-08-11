import { MigrationInterface, QueryRunner } from "typeorm";

export class RecoveryLogs1777200000000 implements MigrationInterface {
  name = "RecoveryLogs1777200000000";

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `CREATE TABLE IF NOT EXISTS "Registros_Recuperacion" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "user_id" character varying NOT NULL, "fecha" date NOT NULL, "horas_sueno" double precision, "hrv_estado" character varying(20), "frecuencia_cardiaca_reposo" integer, "readiness_score" integer NOT NULL, "fuente" character varying(50) NOT NULL DEFAULT 'mi_fitness_health_connect', "notas_ia" text, "created_at" TIMESTAMP NOT NULL DEFAULT now(), CONSTRAINT "PK_RegistrosRecuperacion" PRIMARY KEY ("id"))`,
    );
    await queryRunner.query(
      `CREATE INDEX "IDX_RegistrosRecuperacion_UserId" ON "Registros_Recuperacion" ("user_id")`,
    );
    await queryRunner.query(
      `CREATE INDEX "IDX_RegistrosRecuperacion_Fecha" ON "Registros_Recuperacion" ("fecha")`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX "IDX_RegistrosRecuperacion_Fecha"`);
    await queryRunner.query(`DROP INDEX "IDX_RegistrosRecuperacion_UserId"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "Registros_Recuperacion"`);
  }
}
