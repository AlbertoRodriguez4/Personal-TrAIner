"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.AddMacrosGoals1777150000000 = void 0;
class AddMacrosGoals1777150000000 {
    name = "AddMacrosGoals1777150000000";
    async up(queryRunner) {
        await queryRunner.query(`ALTER TABLE "Perfiles_Usuario" ADD COLUMN IF NOT EXISTS "meta_kcal" numeric(7,2)`);
        await queryRunner.query(`ALTER TABLE "Perfiles_Usuario" ADD COLUMN IF NOT EXISTS "meta_proteinas_g" numeric(6,2)`);
        await queryRunner.query(`ALTER TABLE "Perfiles_Usuario" ADD COLUMN IF NOT EXISTS "meta_carbohidratos_g" numeric(6,2)`);
        await queryRunner.query(`ALTER TABLE "Perfiles_Usuario" ADD COLUMN IF NOT EXISTS "meta_grasas_g" numeric(6,2)`);
    }
    async down(queryRunner) {
        await queryRunner.query(`ALTER TABLE "Perfiles_Usuario" DROP COLUMN IF EXISTS "meta_grasas_g"`);
        await queryRunner.query(`ALTER TABLE "Perfiles_Usuario" DROP COLUMN IF EXISTS "meta_carbohidratos_g"`);
        await queryRunner.query(`ALTER TABLE "Perfiles_Usuario" DROP COLUMN IF EXISTS "meta_proteinas_g"`);
        await queryRunner.query(`ALTER TABLE "Perfiles_Usuario" DROP COLUMN IF EXISTS "meta_kcal"`);
    }
}
exports.AddMacrosGoals1777150000000 = AddMacrosGoals1777150000000;
