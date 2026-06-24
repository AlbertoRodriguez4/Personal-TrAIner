"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.InicializarTablas1776364707848 = void 0;
class InicializarTablas1776364707848 {
    name = 'InicializarTablas1776364707848';
    async up(queryRunner) {
        await queryRunner.query(`CREATE TABLE "Usuarios" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "nombre_completo" character varying NOT NULL, "email" character varying NOT NULL, "fecha_nacimiento" date NOT NULL, "estatura_base_cm" numeric(6,2) NOT NULL, "peso_base_kg" numeric(6,2) NOT NULL, "mapeo_identidad" character varying NOT NULL, "fecha_creacion" TIMESTAMP NOT NULL DEFAULT now(), CONSTRAINT "UQ_ca3e46c76538a31e48348447503" UNIQUE ("email"), CONSTRAINT "PK_6b4c9e5c7d35b294307b3fd0fea" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE TABLE "Registros_Nutricionales_Cualitativos" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "usuario_id" uuid NOT NULL, "fecha_comida" TIMESTAMP NOT NULL, "clasificacion_nova" integer NOT NULL, "distribucion_macronutrientes_volumetrica" jsonb NOT NULL, "resumen_semantico_ia" text NOT NULL, CONSTRAINT "PK_8c555123da2a2f1e047a86ac2b5" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE TABLE "Facturacion_Suscripciones" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "usuario_id" uuid NOT NULL, "id_pasarela_pago" character varying NOT NULL, "estado_suscripcion" character varying NOT NULL, CONSTRAINT "PK_605ad6ba6349a09c06a89481ae6" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE TABLE "Evaluaciones_Posturales_Visuales" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "usuario_id" uuid NOT NULL, "fecha_evaluacion" TIMESTAMP NOT NULL, "porcentaje_grasa_estimado" numeric(6,2) NOT NULL, "tejido_adiposo_visceral_estimado" numeric(6,2) NOT NULL, "asimetria_muscular_detectada" jsonb NOT NULL, "vectores_esqueleticos" jsonb NOT NULL, CONSTRAINT "PK_36db37f04018f01822c74cf369c" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE TABLE "Densitometrias_DEXA" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "usuario_id" uuid NOT NULL, "fecha_escaneo" date NOT NULL, "volumen_vat" numeric(8,2) NOT NULL, "relacion_androide_ginoide" numeric(6,3) NOT NULL, "indice_masa_libre_grasa_ffmi" numeric(6,2) NOT NULL, "t_scores_oseos" jsonb NOT NULL, "payload_fhir" jsonb NOT NULL, CONSTRAINT "PK_84a85fed5d2a585a352bf9d8363" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE TABLE "Sesiones_Entrenamiento" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "usuario_id" uuid NOT NULL, "fecha_inicio" TIMESTAMP NOT NULL, "fecha_fin" TIMESTAMP NOT NULL, "carga_trabajo_calculada" numeric(8,2) NOT NULL, CONSTRAINT "PK_06a3b1db7056f17583ce7503036" PRIMARY KEY ("id"))`);
    }
    async down(queryRunner) {
        await queryRunner.query(`DROP TABLE "Sesiones_Entrenamiento"`);
        await queryRunner.query(`DROP TABLE "Densitometrias_DEXA"`);
        await queryRunner.query(`DROP TABLE "Evaluaciones_Posturales_Visuales"`);
        await queryRunner.query(`DROP TABLE "Facturacion_Suscripciones"`);
        await queryRunner.query(`DROP TABLE "Registros_Nutricionales_Cualitativos"`);
        await queryRunner.query(`DROP TABLE "Usuarios"`);
    }
}
exports.InicializarTablas1776364707848 = InicializarTablas1776364707848;
