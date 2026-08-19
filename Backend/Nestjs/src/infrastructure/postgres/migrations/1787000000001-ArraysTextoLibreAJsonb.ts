import { MigrationInterface, QueryRunner } from "typeorm";

/// `simple-array` de TypeORM serializa a una única columna `text` con los
/// elementos unidos por comas. Sirve para listas de palabras sueltas
/// (`angulos_fotos`, `grupos_musculares_*`, que además vienen de un enum), pero
/// NO para frases: en cuanto un elemento contiene una coma — y las frases que
/// redacta la IA las tienen casi siempre — al leerlo se parte en varios.
///
/// Comprobado en vivo: `banderas_rojas` con 2 frases se guardaba como
/// "Valores elevados de glucosa, HbA1c, colesterol y triglicéridos.,Niveles
/// bajos de ferritina y vitamina D." y volvía como 4 elementos.
///
/// `puntos_fuertes_fisicos` y `areas_mejora_fisicas` ya arrastraban el mismo
/// fallo antes de este cambio; se convierten aquí porque el nuevo análisis por
/// fotos escribe frases en ellas.
export class ArraysTextoLibreAJsonb1787000000001 implements MigrationInterface {
  name = "ArraysTextoLibreAJsonb1787000000001";

  public async up(queryRunner: QueryRunner): Promise<void> {
    // Los datos ya guardados se convierten con el mismo criterio con el que se
    // venían leyendo (split por comas): no se puede recuperar lo que ya se
    // partió, pero al menos no se pierde nada más.
    await queryRunner.query(
      `ALTER TABLE "Informes_Clinicos"
        ALTER COLUMN "hallazgos_clave" TYPE jsonb USING to_jsonb(string_to_array("hallazgos_clave", ',')),
        ALTER COLUMN "banderas_rojas"  TYPE jsonb USING to_jsonb(string_to_array("banderas_rojas", ','))`,
    );
    await queryRunner.query(
      `ALTER TABLE "Analisis_Fisico_Records"
        ALTER COLUMN "puntos_fuertes_fisicos" TYPE jsonb USING to_jsonb(string_to_array("puntos_fuertes_fisicos", ',')),
        ALTER COLUMN "areas_mejora_fisicas"   TYPE jsonb USING to_jsonb(string_to_array("areas_mejora_fisicas", ','))`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "Analisis_Fisico_Records"
        ALTER COLUMN "areas_mejora_fisicas"   TYPE text USING array_to_string(ARRAY(SELECT jsonb_array_elements_text("areas_mejora_fisicas")), ','),
        ALTER COLUMN "puntos_fuertes_fisicos" TYPE text USING array_to_string(ARRAY(SELECT jsonb_array_elements_text("puntos_fuertes_fisicos")), ',')`,
    );
    await queryRunner.query(
      `ALTER TABLE "Informes_Clinicos"
        ALTER COLUMN "banderas_rojas"  TYPE text USING array_to_string(ARRAY(SELECT jsonb_array_elements_text("banderas_rojas")), ','),
        ALTER COLUMN "hallazgos_clave" TYPE text USING array_to_string(ARRAY(SELECT jsonb_array_elements_text("hallazgos_clave")), ',')`,
    );
  }
}
