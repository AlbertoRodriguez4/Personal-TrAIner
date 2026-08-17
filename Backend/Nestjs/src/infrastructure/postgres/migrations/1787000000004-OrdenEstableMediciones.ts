import { MigrationInterface, QueryRunner } from "typeorm";

/// `fecha_escaneo` es un `date` sin hora, así que dos mediciones del mismo día
/// empatan y "la última" quedaba a lo que devolviera Postgres, que no garantiza
/// ningún orden. En la práctica: te pesas por la mañana, corriges por la tarde,
/// y el coach sigue leyendo la de la mañana.
///
/// `fecha_registro` desempata por orden de inserción real. Las filas que ya
/// existen se quedan con `CURRENT_TIMESTAMP`, que no reconstruye su orden
/// original pero tampoco lo empeora: hasta ahora no había ninguno.
export class OrdenEstableMediciones1787000000004 implements MigrationInterface {
  name = "OrdenEstableMediciones1787000000004";

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "Densitometrias_DEXA"
        ADD "fecha_registro" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP`,
    );
    await queryRunner.query(
      `CREATE INDEX "IDX_densitometrias_usuario_fecha"
        ON "Densitometrias_DEXA" ("user_id", "fecha_escaneo" DESC, "fecha_registro" DESC)`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX "IDX_densitometrias_usuario_fecha"`);
    await queryRunner.query(
      `ALTER TABLE "Densitometrias_DEXA" DROP COLUMN "fecha_registro"`,
    );
  }
}
