import { MigrationInterface, QueryRunner } from "typeorm";

/// Las básculas de bioimpedancia de consumo (Fitdays, Tanita, InBody) imprimen
/// bastante más que un DEXA de composición: porcentaje de músculo además de los
/// kg, músculo esquelético aparte, proteína en kg y en %, agua en kg y en %,
/// grasa subcutánea, edad corporal y un "peso estándar" del fabricante.
///
/// Faltaban todos, y el usuario que subía el informe de su báscula veía la mitad
/// de su pantalla en blanco.
export class CamposBioimpedancia1787000000003 implements MigrationInterface {
  name = "CamposBioimpedancia1787000000003";

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "Densitometrias_DEXA"
        ADD "musculo_pct"             numeric(5,2),
        ADD "musculo_esqueletico_pct" numeric(5,2),
        ADD "proteina_kg"             numeric(6,2),
        ADD "proteina_pct"            numeric(5,2),
        ADD "agua_corporal_kg"        numeric(6,2),
        ADD "grasa_subcutanea_pct"    numeric(5,2),
        ADD "edad_corporal"           integer,
        ADD "peso_ideal_kg"           numeric(6,2)`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "Densitometrias_DEXA"
        DROP COLUMN "peso_ideal_kg",
        DROP COLUMN "edad_corporal",
        DROP COLUMN "grasa_subcutanea_pct",
        DROP COLUMN "agua_corporal_kg",
        DROP COLUMN "proteina_pct",
        DROP COLUMN "proteina_kg",
        DROP COLUMN "musculo_esqueletico_pct",
        DROP COLUMN "musculo_pct"`,
    );
  }
}
