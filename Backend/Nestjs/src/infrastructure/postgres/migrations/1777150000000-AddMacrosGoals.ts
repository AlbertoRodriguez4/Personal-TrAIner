import { MigrationInterface, QueryRunner } from "typeorm";

export class AddMacrosGoals1777150000000 implements MigrationInterface {
  name = "AddMacrosGoals1777150000000";

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "Perfiles_Usuario" ADD COLUMN IF NOT EXISTS "meta_kcal" numeric(7,2)`,
    );
    await queryRunner.query(
      `ALTER TABLE "Perfiles_Usuario" ADD COLUMN IF NOT EXISTS "meta_proteinas_g" numeric(6,2)`,
    );
    await queryRunner.query(
      `ALTER TABLE "Perfiles_Usuario" ADD COLUMN IF NOT EXISTS "meta_carbohidratos_g" numeric(6,2)`,
    );
    await queryRunner.query(
      `ALTER TABLE "Perfiles_Usuario" ADD COLUMN IF NOT EXISTS "meta_grasas_g" numeric(6,2)`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "Perfiles_Usuario" DROP COLUMN IF EXISTS "meta_grasas_g"`,
    );
    await queryRunner.query(
      `ALTER TABLE "Perfiles_Usuario" DROP COLUMN IF EXISTS "meta_carbohidratos_g"`,
    );
    await queryRunner.query(
      `ALTER TABLE "Perfiles_Usuario" DROP COLUMN IF EXISTS "meta_proteinas_g"`,
    );
    await queryRunner.query(
      `ALTER TABLE "Perfiles_Usuario" DROP COLUMN IF EXISTS "meta_kcal"`,
    );
  }
}