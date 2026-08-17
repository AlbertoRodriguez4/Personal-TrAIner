import { MigrationInterface, QueryRunner } from "typeorm";

export class ClinicaYFisico1787000000000 implements MigrationInterface {
  name = "ClinicaYFisico1787000000000";

  public async up(queryRunner: QueryRunner): Promise<void> {
    // ===== Informes clínicos (documento digerido por la IA) =====
    await queryRunner.query(
      `CREATE TABLE IF NOT EXISTS "Informes_Clinicos" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "user_id" character varying NOT NULL, "fecha_subida" TIMESTAMP NOT NULL DEFAULT now(), "fecha_informe" date, "tipo_documento" character varying(40) NOT NULL DEFAULT 'analitica', "nombre_archivo" character varying(255), "resumen_ia" text NOT NULL, "hallazgos_clave" text, "implicaciones_entrenamiento" text, "implicaciones_nutricion" text, "banderas_rojas" text, "fuentes_consultadas" jsonb, "confianza_extraccion" character varying(20), CONSTRAINT "PK_InformesClinicos" PRIMARY KEY ("id"))`,
    );
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "IDX_InformesClinicos_UserId" ON "Informes_Clinicos" ("user_id")`,
    );

    // ===== Biomarcadores (una fila por medición, para poder ver tendencia) =====
    await queryRunner.query(
      `CREATE TABLE IF NOT EXISTS "Biomarcadores_Clinicos" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "user_id" character varying NOT NULL, "report_id" uuid, "fecha" date NOT NULL, "codigo" character varying(60) NOT NULL, "nombre" character varying(120) NOT NULL, "valor" numeric(12,4) NOT NULL, "unidad" character varying(30), "rango_min" numeric(12,4), "rango_max" numeric(12,4), "estado" character varying(20) NOT NULL DEFAULT 'desconocido', "relevancia_fisico" text, "origen" character varying(20) NOT NULL DEFAULT 'documento_ia', CONSTRAINT "PK_BiomarcadoresClinicos" PRIMARY KEY ("id"), CONSTRAINT "FK_BiomarcadoresClinicos_Informe" FOREIGN KEY ("report_id") REFERENCES "Informes_Clinicos"("id") ON DELETE CASCADE)`,
    );
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "IDX_BiomarcadoresClinicos_UserId" ON "Biomarcadores_Clinicos" ("user_id")`,
    );
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "IDX_BiomarcadoresClinicos_Fecha" ON "Biomarcadores_Clinicos" ("fecha")`,
    );
    // La consulta caliente es "último valor de cada código de este usuario".
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "IDX_BiomarcadoresClinicos_UserCodigoFecha" ON "Biomarcadores_Clinicos" ("user_id", "codigo", "fecha" DESC)`,
    );

    // ===== Campos nuevos del análisis físico =====
    await queryRunner.query(
      `ALTER TABLE "Analisis_Fisico_Records"
        ADD COLUMN IF NOT EXISTS "origen" character varying(30) NOT NULL DEFAULT 'chat',
        ADD COLUMN IF NOT EXISTS "num_fotos" integer NOT NULL DEFAULT 0,
        ADD COLUMN IF NOT EXISTS "angulos_fotos" text,
        ADD COLUMN IF NOT EXISTS "grupos_musculares_retrasados" text,
        ADD COLUMN IF NOT EXISTS "grupos_musculares_dominantes" text,
        ADD COLUMN IF NOT EXISTS "medidas_estimadas" jsonb,
        ADD COLUMN IF NOT EXISTS "postura_observaciones" text,
        ADD COLUMN IF NOT EXISTS "prioridad_entrenamiento" text,
        ADD COLUMN IF NOT EXISTS "fuentes_consultadas" jsonb`,
    );
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "IDX_AnalisisFisicoRecords_UserFecha" ON "Analisis_Fisico_Records" ("user_id", "fecha_analisis" DESC)`,
    );

    // ===== Fotos del físico =====
    await queryRunner.query(
      `CREATE TABLE IF NOT EXISTS "Fotos_Fisico" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "user_id" character varying NOT NULL, "record_id" uuid NOT NULL, "angulo" character varying(20) NOT NULL DEFAULT 'otro', "mime_type" character varying(40) NOT NULL DEFAULT 'image/jpeg', "imagen" bytea NOT NULL, "created_at" TIMESTAMP NOT NULL DEFAULT now(), CONSTRAINT "PK_FotosFisico" PRIMARY KEY ("id"), CONSTRAINT "FK_FotosFisico_Record" FOREIGN KEY ("record_id") REFERENCES "Analisis_Fisico_Records"("id") ON DELETE CASCADE)`,
    );
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "IDX_FotosFisico_UserId" ON "Fotos_Fisico" ("user_id")`,
    );
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "IDX_FotosFisico_RecordId" ON "Fotos_Fisico" ("record_id")`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX IF EXISTS "IDX_FotosFisico_RecordId"`);
    await queryRunner.query(`DROP INDEX IF EXISTS "IDX_FotosFisico_UserId"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "Fotos_Fisico"`);

    await queryRunner.query(`DROP INDEX IF EXISTS "IDX_AnalisisFisicoRecords_UserFecha"`);
    await queryRunner.query(
      `ALTER TABLE "Analisis_Fisico_Records"
        DROP COLUMN IF EXISTS "fuentes_consultadas",
        DROP COLUMN IF EXISTS "prioridad_entrenamiento",
        DROP COLUMN IF EXISTS "postura_observaciones",
        DROP COLUMN IF EXISTS "medidas_estimadas",
        DROP COLUMN IF EXISTS "grupos_musculares_dominantes",
        DROP COLUMN IF EXISTS "grupos_musculares_retrasados",
        DROP COLUMN IF EXISTS "angulos_fotos",
        DROP COLUMN IF EXISTS "num_fotos",
        DROP COLUMN IF EXISTS "origen"`,
    );

    await queryRunner.query(`DROP INDEX IF EXISTS "IDX_BiomarcadoresClinicos_UserCodigoFecha"`);
    await queryRunner.query(`DROP INDEX IF EXISTS "IDX_BiomarcadoresClinicos_Fecha"`);
    await queryRunner.query(`DROP INDEX IF EXISTS "IDX_BiomarcadoresClinicos_UserId"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "Biomarcadores_Clinicos"`);

    await queryRunner.query(`DROP INDEX IF EXISTS "IDX_InformesClinicos_UserId"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "Informes_Clinicos"`);
  }
}
