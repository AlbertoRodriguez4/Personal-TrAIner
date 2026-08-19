import "dotenv/config";
import "reflect-metadata";
import { DataSource } from "typeorm";
import { User } from "../../modules/identity/entities/user.entity";
import { NutritionLog } from "../../modules/nutrition/entities/nutrition_log.entity";
import { Subscription } from "../../modules/billing/entities/subscription.entity";
import { PostureEvaluation } from "../../modules/physical_analysis/entities/posture_evaluation.entity";
import { DexaScan } from "../../modules/clinical_data/entities/dexa_scan.entity";
import { TrainingSession } from "../../modules/training_sessions/entities/training_session.entity";
import { UserProfile } from "../../modules/user_profile/entities/user_profile.entity";
import { BodyAnalysisRecord } from "../../modules/body_analysis/entities/body_analysis_record.entity";
import { Routine } from "../../modules/routine/entities/routine.entity";
import { RoutineDay } from "../../modules/routine/entities/routine_day.entity";
import { Exercise } from "../../modules/routine/entities/exercise.entity";
import { ExerciseCatalog } from "../../modules/exercises_catalog/entities/exercise_catalog.entity";
import { RecoveryLog } from "../../modules/recovery/entities/recovery_log.entity";
import { Supplement } from "../../modules/supplements/entities/supplement.entity";
import { SupplementLog } from "../../modules/supplements/entities/supplement_log.entity";
import { ClinicalReport } from "../../modules/clinical_data/entities/clinical_report.entity";
import { ClinicalMarker } from "../../modules/clinical_data/entities/clinical_marker.entity";
import { PhysiquePhoto } from "../../modules/body_analysis/entities/physique_photo.entity";

export const AppDataSource = new DataSource({
    type: "postgres",
    host: process.env.DB_HOST || "localhost",
    port: parseInt(process.env.DB_PORT || "5435"),
    username: process.env.DB_USERNAME,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_DATABASE,
    synchronize: false,
    logging: true,
    entities: [
        User,
        NutritionLog,
        Subscription,
        PostureEvaluation,
        DexaScan,
        TrainingSession,
        UserProfile,
        BodyAnalysisRecord,
        Routine,
        RoutineDay,
        Exercise,
        ExerciseCatalog,
        RecoveryLog,
        Supplement,
        SupplementLog,
        ClinicalReport,
        ClinicalMarker,
        PhysiquePhoto,
    ],
    // Relativo a este fichero y aceptando .ts y .js, para que el mismo
    // data-source sirva en desarrollo (ts-node sobre src/) y en el contenedor de
    // producción (JavaScript ya compilado en dist/). Con la ruta fija a
    // "src/**/*.ts" que había antes, las migraciones no se encontraban en el
    // contenedor: ts-node es devDependency y no está en la imagen final.
    migrations: [__dirname + "/migrations/*{.ts,.js}"],
    subscribers: [],
});
