"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.RoutineModule1776856451962 = void 0;
class RoutineModule1776856451962 {
    name = 'RoutineModule1776856451962';
    async up(queryRunner) {
        await queryRunner.query(`CREATE TABLE "routines" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "name" character varying NOT NULL, "activity_type" character varying NOT NULL, "description" character varying, "created_at" TIMESTAMP NOT NULL DEFAULT now(), "updated_at" TIMESTAMP NOT NULL DEFAULT now(), CONSTRAINT "PK_Routines" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE TABLE "routine_days" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "day_of_week" character varying NOT NULL, "focus" character varying, "routine_id" uuid, CONSTRAINT "PK_RoutineDays" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE TABLE "exercises" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "name" character varying NOT NULL, "sets" integer, "reps" character varying, "weight" double precision, "duration" character varying, "notes" text, "routine_day_id" uuid, CONSTRAINT "PK_Exercises" PRIMARY KEY ("id"))`);
        await queryRunner.query(`ALTER TABLE "routine_days" ADD CONSTRAINT "FK_RoutineDays_Routine" FOREIGN KEY ("routine_id") REFERENCES "routines"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "exercises" ADD CONSTRAINT "FK_Exercises_RoutineDay" FOREIGN KEY ("routine_day_id") REFERENCES "routine_days"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
    }
    async down(queryRunner) {
        await queryRunner.query(`ALTER TABLE "exercises" DROP CONSTRAINT "FK_Exercises_RoutineDay"`);
        await queryRunner.query(`ALTER TABLE "routine_days" DROP CONSTRAINT "FK_RoutineDays_Routine"`);
        await queryRunner.query(`DROP TABLE "exercises"`);
        await queryRunner.query(`DROP TABLE "routine_days"`);
        await queryRunner.query(`DROP TABLE "routines"`);
    }
}
exports.RoutineModule1776856451962 = RoutineModule1776856451962;
