import { MigrationInterface, QueryRunner } from "typeorm";

export class Actualizacion1776437687161 implements MigrationInterface {
    name = 'Actualizacion1776437687161'

    public async up(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`ALTER TABLE "Usuarios" ALTER COLUMN "mapeo_identidad" DROP NOT NULL`);
    }

    public async down(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`ALTER TABLE "Usuarios" ALTER COLUMN "mapeo_identidad" SET NOT NULL`);
    }

}
