import { MigrationInterface, QueryRunner } from "typeorm";

export class Supplements1786800000000 implements MigrationInterface {
  name = "Supplements1786800000000";

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `CREATE TABLE IF NOT EXISTS "Suplementos_Usuario" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "user_id" character varying NOT NULL, "nombre" character varying(120) NOT NULL, "dosis" character varying(60), "activo" boolean NOT NULL DEFAULT true, "created_at" TIMESTAMP NOT NULL DEFAULT now(), CONSTRAINT "PK_SuplementosUsuario" PRIMARY KEY ("id"))`,
    );
    await queryRunner.query(
      `CREATE INDEX "IDX_SuplementosUsuario_UserId" ON "Suplementos_Usuario" ("user_id")`,
    );

    await queryRunner.query(
      `CREATE TABLE IF NOT EXISTS "Suplementos_Registro_Diario" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "user_id" character varying NOT NULL, "supplement_id" uuid NOT NULL, "fecha" date NOT NULL, CONSTRAINT "PK_SuplementosRegistroDiario" PRIMARY KEY ("id"), CONSTRAINT "UQ_SuplementosRegistroDiario_SupplementFecha" UNIQUE ("supplement_id", "fecha"), CONSTRAINT "FK_SuplementosRegistroDiario_Supplement" FOREIGN KEY ("supplement_id") REFERENCES "Suplementos_Usuario"("id") ON DELETE CASCADE)`,
    );
    await queryRunner.query(
      `CREATE INDEX "IDX_SuplementosRegistroDiario_UserId" ON "Suplementos_Registro_Diario" ("user_id")`,
    );
    await queryRunner.query(
      `CREATE INDEX "IDX_SuplementosRegistroDiario_Fecha" ON "Suplementos_Registro_Diario" ("fecha")`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX "IDX_SuplementosRegistroDiario_Fecha"`);
    await queryRunner.query(`DROP INDEX "IDX_SuplementosRegistroDiario_UserId"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "Suplementos_Registro_Diario"`);
    await queryRunner.query(`DROP INDEX "IDX_SuplementosUsuario_UserId"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "Suplementos_Usuario"`);
  }
}
