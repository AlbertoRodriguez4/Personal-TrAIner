import { MigrationInterface, QueryRunner } from "typeorm";

export class AddUserProfileExtraFields1777400000000 implements MigrationInterface {
  name = "AddUserProfileExtraFields1777400000000";

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "Perfiles_Usuario" ADD COLUMN IF NOT EXISTS "actividades" text`,
    );
    await queryRunner.query(
      `ALTER TABLE "Perfiles_Usuario" ADD COLUMN IF NOT EXISTS "sexo" character varying(30)`,
    );
    await queryRunner.query(
      `ALTER TABLE "Perfiles_Usuario" ADD COLUMN IF NOT EXISTS "fc_reposo" integer`,
    );
    await queryRunner.query(
      `ALTER TABLE "Perfiles_Usuario" ADD COLUMN IF NOT EXISTS "horas_sueno_habitual" numeric(4,2)`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "Perfiles_Usuario" DROP COLUMN IF EXISTS "horas_sueno_habitual"`,
    );
    await queryRunner.query(
      `ALTER TABLE "Perfiles_Usuario" DROP COLUMN IF EXISTS "fc_reposo"`,
    );
    await queryRunner.query(
      `ALTER TABLE "Perfiles_Usuario" DROP COLUMN IF EXISTS "sexo"`,
    );
    await queryRunner.query(
      `ALTER TABLE "Perfiles_Usuario" DROP COLUMN IF EXISTS "actividades"`,
    );
  }
}
