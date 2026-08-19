import { MigrationInterface, QueryRunner } from "typeorm";

export class RoutineActivaYMigracionDatos1777300000000 implements MigrationInterface {
    name = 'RoutineActivaYMigracionDatos1777300000000';

    public async up(queryRunner: QueryRunner): Promise<void> {
        // a) Añade las columnas que faltan
        await queryRunner.query(`ALTER TABLE "routines" ADD COLUMN IF NOT EXISTS "activa" boolean NOT NULL DEFAULT true`);
        await queryRunner.query(`ALTER TABLE "exercises" ADD COLUMN IF NOT EXISTS "rest_seconds" integer`);
        
        // Ensure userId exists just in case (as entity has it, but old migration didn't show it)
        const routinesColumns = await queryRunner.query(`
            SELECT column_name 
            FROM information_schema.columns 
            WHERE table_name = 'routines' AND column_name = 'userId'
        `);
        if (routinesColumns.length === 0) {
            await queryRunner.query(`ALTER TABLE "routines" ADD COLUMN IF NOT EXISTS "userId" character varying`);
        }

        // b) Comprueba si "Rutinas_Personalizadas" tiene filas
        const rutinas = await queryRunner.query(`SELECT * FROM "Rutinas_Personalizadas"`);
        
        if (rutinas && rutinas.length > 0) {
            for (const r of rutinas) {
                const name = r.nombre_rutina;
                const activityType = r.tipo_entrenamiento;
                const description = r.notas_adicionales;
                const activa = r.activa !== undefined ? r.activa : true;
                const userId = r.user_id;

                const routineInsertResult = await queryRunner.query(
                    `INSERT INTO "routines" (name, activity_type, description, activa, "userId") VALUES ($1, $2, $3, $4, $5) RETURNING id`,
                    [name, activityType, description, activa, userId]
                );
                
                const routineId = routineInsertResult[0].id;
                
                const diasEntrenamiento = r.dias_entrenamiento;
                if (diasEntrenamiento && Array.isArray(diasEntrenamiento)) {
                    for (let i = 0; i < diasEntrenamiento.length; i++) {
                        const d = diasEntrenamiento[i];
                        const numeroDia = d.numero_dia || (i + 1);
                        const dayOfWeekStr = 'Día ' + numeroDia;
                        
                        let focusStr = '';
                        if (d.nombre_dia && d.grupo_muscular) {
                            focusStr = d.nombre_dia + ' — ' + d.grupo_muscular;
                        } else if (d.nombre_dia) {
                            focusStr = d.nombre_dia;
                        } else if (d.grupo_muscular) {
                            focusStr = d.grupo_muscular;
                        }

                        const dayInsertResult = await queryRunner.query(
                            `INSERT INTO "routine_days" (day_of_week, focus, routine_id) VALUES ($1, $2, $3) RETURNING id`,
                            [dayOfWeekStr, focusStr, routineId]
                        );
                        
                        const dayId = dayInsertResult[0].id;
                        
                        const ejercicios = d.ejercicios;
                        if (ejercicios && Array.isArray(ejercicios)) {
                            for (const e of ejercicios) {
                                await queryRunner.query(
                                    `INSERT INTO "exercises" (name, sets, reps, rest_seconds, notes, routine_day_id) VALUES ($1, $2, $3, $4, $5, $6)`,
                                    [e.nombre, e.series, String(e.repeticiones), e.descanso_segundos, e.notas, dayId]
                                );
                            }
                        }
                    }
                }
            }
        }
    }

    public async down(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`ALTER TABLE "exercises" DROP COLUMN "rest_seconds"`);
        await queryRunner.query(`ALTER TABLE "routines" DROP COLUMN "activa"`);
        // No revertimos la copia de datos para preservar rutinas si las hubiera.
    }
}
