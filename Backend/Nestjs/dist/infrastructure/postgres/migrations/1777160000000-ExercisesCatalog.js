"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ExercisesCatalog1777160000000 = void 0;
class ExercisesCatalog1777160000000 {
    name = "ExercisesCatalog1777160000000";
    async up(queryRunner) {
        await queryRunner.query(`CREATE TABLE IF NOT EXISTS "Ejercicios_Catalogo" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "nombre" varchar(100) NOT NULL, "grupo_muscular" varchar(50) NOT NULL, "equipamiento" varchar(50), "descripcion" text, CONSTRAINT "PK_EjerciciosCatalogo" PRIMARY KEY ("id"), CONSTRAINT "UQ_EjerciciosCatalogo_Nombre" UNIQUE ("nombre"))`);
        const ejercicios = [
            ["Press Banca", "Pecho", "Barra", "Press horizontal con barra para pectorales"],
            ["Press Inclinado Mancuernas", "Pecho", "Mancuernas", "Press inclinado para pectoral superior"],
            ["Aperturas con Mancuernas", "Pecho", "Mancuernas", "Apertura para aislamiento de pectoral"],
            ["Sentadilla", "Piernas", "Barra", "Sentadilla con barra libre"],
            ["Peso Muerto", "Espalda", "Barra", "Peso muerto convencional para cadena posterior"],
            ["Peso Muerto Rumano", "Piernas", "Barra", "Variante enfocada en isquiotibiales"],
            ["Dominadas", "Espalda", "Calistenia", "Tracción vertical para dorsales"],
            ["Remo con Barra", "Espalda", "Barra", "Remo inclinado para grosor de dorsal"],
            ["Curl Bíceps con Barra", "Bíceps", "Barra", "Curl bíceps supino"],
            ["Curl Martillo", "Bíceps", "Mancuernas", "Curl neutro para braquial"],
            ["Press de Hombro", "Hombros", "Mancuernas", "Press militar sentado con mancuernas"],
            ["Elevaciones Laterales", "Hombros", "Mancuernas", "Vuelos laterales para deltoide medio"],
            ["Tríceps en Polea", "Tríceps", "Polea", "Extensión de tríceps en polea alta"],
            ["Fondos en Paralelas", "Tríceps", "Calistenia", "Fondos para tríceps y pecho"],
            ["Zancadas", "Piernas", "Mancuernas", "Lunges alternos con mancuernas"],
            ["Curl Femoral", "Piernas", "Máquina", "Curl de isquiotibiales en máquina"],
            ["Elevación de Gemelos", "Piernas", "Máquina", "Calf raises de pie o sentado"],
            ["Plancha", "Core", "Calistenia", "Isometría para core transverso"],
            ["Crunch con Disco", "Core", "Peso", "Encogimientos con disco sobre pecho"],
        ];
        for (const [nombre, grupo, equip, desc] of ejercicios) {
            await queryRunner.query(`INSERT INTO "Ejercicios_Catalogo" ("nombre","grupo_muscular","equipamiento","descripcion")
         VALUES ($1, $2, $3, $4)
         ON CONFLICT ("nombre") DO NOTHING`, [nombre, grupo, equip, desc]);
        }
    }
    async down(queryRunner) {
        await queryRunner.query(`DROP TABLE IF EXISTS "Ejercicios_Catalogo"`);
    }
}
exports.ExercisesCatalog1777160000000 = ExercisesCatalog1777160000000;
