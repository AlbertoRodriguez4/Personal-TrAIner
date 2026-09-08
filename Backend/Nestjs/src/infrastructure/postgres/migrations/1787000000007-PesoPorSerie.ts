import { MigrationInterface, QueryRunner } from "typeorm";

/// Peso por serie, para los ejercicios que se suben en rampa.
///
/// `weight` guarda UN peso para todo el ejercicio, y eso no sirve cuando la
/// pauta es 60-65-70: o se apunta el primero y la app se queda corta las dos
/// series siguientes, o se apunta el ultimo y va sobrada la primera. La columna
/// nueva guarda la lista completa y `weight` se mantiene como el peso de
/// referencia, asi que las rutinas de siempre siguen funcionando igual.
///
/// jsonb y no simple-array: aunque una lista de numeros no sufre el problema de
/// las comas que documenta CLAUDE.md, jsonb da tipos reales y evita tener que
/// parsear texto en cada lectura.
export class PesoPorSerie1787000000007 implements MigrationInterface {
  name = "PesoPorSerie1787000000007";

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "exercises" ADD COLUMN IF NOT EXISTS "weights" jsonb`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "exercises" DROP COLUMN IF EXISTS "weights"`,
    );
  }
}
