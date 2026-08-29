import { MigrationInterface, QueryRunner } from 'typeorm';

import { EJERCICIOS_FREE_EXERCISE_DB } from './data/ejercicios-free-exercise-db';

/// Sube el catálogo de 19 ejercicios escritos a mano a los ~870 de
/// `yuhonas/free-exercise-db`, traducidos al español por
/// `scripts/traducir_catalogo.py`.
///
/// Con 19 ejercicios el "Añadir rápido" no cubría ni un mesociclo: cualquier
/// variante que el usuario buscara terminaba en "ejercicio personalizado",
/// escrito a mano y por tanto invisible para el mapa muscular, que reparte por
/// nombre y por `grupo_muscular` del catálogo.
///
/// Dos cosas que no se ven en el SQL:
///
///  - **`ON CONFLICT DO NOTHING` sobre `nombre`.** Los 19 originales siguen
///    ahí y algunos coinciden en concepto con los nuevos ("Sentadilla" ya
///    existía). Se respeta lo que ya hubiera: puede estar referenciado desde
///    rutinas reales, y sustituirlo cambiaría el id bajo los pies de una
///    rutina que ya lo usa.
///  - **`imagen_url` es nueva y nullable.** Los 19 de siempre no tienen
///    imagen, y la app todavía no las pinta; se guardan ahora para no tener
///    que volver a cruzar 870 filas con el dataset cuando las pinte.
export class CatalogoEjerciciosCompleto1787100000000
  implements MigrationInterface
{
  name = 'CatalogoEjerciciosCompleto1787100000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "Ejercicios_Catalogo" ADD COLUMN IF NOT EXISTS "imagen_url" text`,
    );

    // Por lotes y no en un solo INSERT: Postgres corta en 65535 parámetros por
    // sentencia, y aunque 872 × 5 cabe hoy, un dataset que crezca lo rompería
    // sin avisar y en el sitio menos visible (el deploy, no el build).
    const LOTE = 200;
    for (let i = 0; i < EJERCICIOS_FREE_EXERCISE_DB.length; i += LOTE) {
      const lote = EJERCICIOS_FREE_EXERCISE_DB.slice(i, i + LOTE);
      const marcadores = lote
        .map(
          (_, j) =>
            `($${j * 5 + 1}, $${j * 5 + 2}, $${j * 5 + 3}, $${j * 5 + 4}, $${j * 5 + 5})`,
        )
        .join(', ');
      const parametros = lote.flatMap((e) => [
        e.nombre,
        e.grupo_muscular,
        e.equipamiento,
        e.descripcion,
        e.imagen_url,
      ]);
      await queryRunner.query(
        `INSERT INTO "Ejercicios_Catalogo"
           ("nombre", "grupo_muscular", "equipamiento", "descripcion", "imagen_url")
         VALUES ${marcadores}
         ON CONFLICT ("nombre") DO NOTHING`,
        parametros,
      );
    }
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    // Se borra por `imagen_url IS NOT NULL`, no por la lista de nombres.
    //
    // Parece un rodeo y no lo es: varios nombres traducidos coinciden con los
    // 19 escritos a mano ("Sentadilla" ya existía), y en esos el INSERT no
    // hizo nada por el ON CONFLICT. Borrar por nombre se llevaría por delante
    // el original — una fila que esta migración nunca creó y a la que pueden
    // estar apuntando rutinas reales. La imagen es lo que distingue a los
    // importados: los 19 de siempre no tienen ninguna.
    await queryRunner.query(
      `DELETE FROM "Ejercicios_Catalogo" WHERE "imagen_url" IS NOT NULL`,
    );
    await queryRunner.query(
      `ALTER TABLE "Ejercicios_Catalogo" DROP COLUMN IF EXISTS "imagen_url"`,
    );
  }
}
