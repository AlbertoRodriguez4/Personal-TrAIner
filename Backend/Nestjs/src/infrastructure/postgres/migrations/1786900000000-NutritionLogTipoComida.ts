import { MigrationInterface, QueryRunner } from "typeorm";

export class NutritionLogTipoComida1786900000000 implements MigrationInterface {
  name = "NutritionLogTipoComida1786900000000";

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "Registros_Nutricionales_Cualitativos" ADD COLUMN IF NOT EXISTS "tipo_comida" character varying(20) NOT NULL DEFAULT 'otro'`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "Registros_Nutricionales_Cualitativos" DROP COLUMN IF EXISTS "tipo_comida"`,
    );
  }
}
