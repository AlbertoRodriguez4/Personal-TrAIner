import { MigrationInterface, QueryRunner } from "typeorm";

export class Actualizacion1776437363661 implements MigrationInterface {
    name = 'Actualizacion1776437363661'

    public async up(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`ALTER TABLE "Usuarios" ADD "password" character varying NOT NULL`);
    }

    public async down(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`ALTER TABLE "Usuarios" DROP COLUMN "password"`);
    }

}
