import { MigrationInterface, QueryRunner } from "typeorm";

/// El catálogo tiene `imagen_url` desde la importación de `free-exercise-db`
/// (migración 1787100000000), pero el ejercicio ya metido en una rutina no la
/// tenía: la miniatura solo se veía mientras se elegía del catálogo y
/// desaparecía en cuanto el ejercicio pasaba a formar parte del plan.
///
/// Se copia al ejercicio en vez de resolverse por nombre en cada lectura porque
/// el nombre de un ejercicio de rutina es libre y editable (ver la nota de la
/// entidad). El relleno de abajo es un `UPDATE` puntual para las rutinas ya
/// guardadas, cruzando por nombre sin tildes ni mayúsculas — lo mismo que hace
/// `RoutineService.completarImagenes` para los ejercicios nuevos.
export class ImagenEjercicioRutina1787200000000 implements MigrationInterface {
  name = "ImagenEjercicioRutina1787200000000";

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "exercises" ADD COLUMN IF NOT EXISTS "imagen_url" text`,
    );

    // `unaccent` no está instalada en la base de datos de producción y no se
    // activa aquí solo para esto: `translate` cubre las cinco vocales
    // acentuadas y la eñe, que es todo lo que aparece en nombres de ejercicios
    // en español ("Extensión de tríceps", "Elevación de gemelos de pie").
    await queryRunner.query(`
      UPDATE "exercises" e
      SET "imagen_url" = c."imagen_url"
      FROM "Ejercicios_Catalogo" c
      WHERE e."imagen_url" IS NULL
        AND c."imagen_url" IS NOT NULL
        AND translate(lower(btrim(e."name")), 'áéíóúüñ', 'aeiouun')
          = translate(lower(btrim(c."nombre")), 'áéíóúüñ', 'aeiouun')
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "exercises" DROP COLUMN IF EXISTS "imagen_url"`,
    );
  }
}
