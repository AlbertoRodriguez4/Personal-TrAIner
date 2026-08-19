import { MigrationInterface, QueryRunner } from "typeorm";

/// `training_session` solo guardaba el plan (tipo, ejercicios, estado): ni una
/// sola métrica de lo que de verdad pasó en el entrenamiento. Ni analizar una
/// sesión sola ni compararla con las demás era posible porque no había con qué.
///
/// Se añaden las métricas clave (duración, calorías, FC media/máx, distancia)
/// y de dónde salió la sesión (`origen`): una narrada por chat puede no traer
/// ninguna, una rastreada en vivo con la banda BLE trae FC real, una
/// sincronizada de Health Connect trae casi todas. `origen_id` es lo que evita
/// duplicar una sesión de Health Connect si la sincronización se repite — no
/// hay otro identificador estable disponible desde el plugin que usa la app.
export class MetricasSesionEntrenamiento1787000000005 implements MigrationInterface {
  name = "MetricasSesionEntrenamiento1787000000005";

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "Sesiones_Entrenamiento"
        ADD "duracion_minutos"           integer,
        ADD "calorias_kcal"              integer,
        ADD "frecuencia_cardiaca_media"  integer,
        ADD "frecuencia_cardiaca_max"    integer,
        ADD "distancia_km"               numeric(6,2),
        ADD "origen"                     character varying(20) NOT NULL DEFAULT 'manual',
        ADD "origen_id"                  character varying(60)`,
    );
    await queryRunner.query(
      `CREATE INDEX "IDX_training_session_origen_id" ON "Sesiones_Entrenamiento" ("user_id", "origen_id")`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX "IDX_training_session_origen_id"`);
    await queryRunner.query(
      `ALTER TABLE "Sesiones_Entrenamiento"
        DROP COLUMN "origen_id",
        DROP COLUMN "origen",
        DROP COLUMN "distancia_km",
        DROP COLUMN "frecuencia_cardiaca_max",
        DROP COLUMN "frecuencia_cardiaca_media",
        DROP COLUMN "calorias_kcal",
        DROP COLUMN "duracion_minutos"`,
    );
  }
}
