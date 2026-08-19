import { MigrationInterface, QueryRunner } from "typeorm";

export class NutritionLogNombreAlimento1787000000006 implements MigrationInterface {
  name = "NutritionLogNombreAlimento1787000000006";

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "Registros_Nutricionales_Cualitativos" ADD COLUMN IF NOT EXISTS "nombre_alimento" character varying(150)`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "Registros_Nutricionales_Cualitativos" DROP COLUMN IF EXISTS "nombre_alimento"`,
    );
  }
}
