import { MigrationInterface, QueryRunner } from "typeorm";

/// `Densitometrias_DEXA` guardaba tres cifras y las tres obligatorias
/// (porcentaje de grasa, masa muscular y densidad ósea). Eso dejaba fuera
/// justo lo que se usa a diario — peso, IMC, masa grasa, masa magra — y hacía
/// imposible registrar una báscula de bioimpedancia, que no da densidad ósea:
/// o inventabas un número o no guardabas nada.
///
/// Aquí la tabla pasa a ser un registro de **composición corporal** completo, y
/// todas las métricas quedan opcionales. Los mínimos del usuario (peso y
/// altura) siguen viviendo en `Usuarios`, que es lo único que hace falta para
/// calcular un plan de nutrición.
export class ComposicionCorporal1787000000002 implements MigrationInterface {
  name = "ComposicionCorporal1787000000002";

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "Densitometrias_DEXA"
        ALTER COLUMN "porcentaje_grasa" DROP NOT NULL,
        ALTER COLUMN "masa_muscular_kg" DROP NOT NULL,
        ALTER COLUMN "densidad_osea"    DROP NOT NULL`,
    );

    await queryRunner.query(
      `ALTER TABLE "Densitometrias_DEXA"
        ADD "metodo"            character varying(30) NOT NULL DEFAULT 'dexa',
        ADD "peso_kg"           numeric(6,2),
        ADD "imc"               numeric(5,2),
        ADD "masa_grasa_kg"     numeric(6,2),
        ADD "masa_magra_kg"     numeric(6,2),
        ADD "masa_osea_kg"      numeric(5,2),
        ADD "agua_corporal_pct" numeric(5,2),
        ADD "grasa_visceral"    numeric(6,2),
        ADD "tmb_kcal"          integer,
        ADD "ffmi"              numeric(5,2),
        ADD "notas"             text`,
    );

    // Las filas que ya existen traen densidad ósea, así que salieron de un DEXA
    // de verdad; se quedan con el método por defecto. No se les puede derivar el
    // peso (no lo guardaban) y se deja a NULL en vez de estimarlo desde la masa
    // muscular, que no es la masa magra y daría un peso falso.
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "Densitometrias_DEXA"
        DROP COLUMN "notas",
        DROP COLUMN "ffmi",
        DROP COLUMN "tmb_kcal",
        DROP COLUMN "grasa_visceral",
        DROP COLUMN "agua_corporal_pct",
        DROP COLUMN "masa_osea_kg",
        DROP COLUMN "masa_magra_kg",
        DROP COLUMN "masa_grasa_kg",
        DROP COLUMN "imc",
        DROP COLUMN "peso_kg",
        DROP COLUMN "metodo"`,
    );

    // Volver a NOT NULL exige que no queden nulos: las mediciones que se
    // guardaron sin estos campos (una báscula, por ejemplo) no caben en el
    // esquema antiguo y se borran, que es lo que había antes de esta migración.
    await queryRunner.query(
      `DELETE FROM "Densitometrias_DEXA"
        WHERE "porcentaje_grasa" IS NULL
           OR "masa_muscular_kg" IS NULL
           OR "densidad_osea" IS NULL`,
    );
    await queryRunner.query(
      `ALTER TABLE "Densitometrias_DEXA"
        ALTER COLUMN "porcentaje_grasa" SET NOT NULL,
        ALTER COLUMN "masa_muscular_kg" SET NOT NULL,
        ALTER COLUMN "densidad_osea"    SET NOT NULL`,
    );
  }
}
