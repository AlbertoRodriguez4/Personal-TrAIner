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
import { CustomRoutine } from "../../modules/custom_routine/entities/custom_routine.entity";
import { BodyAnalysisRecord } from "../../modules/body_analysis/entities/body_analysis_record.entity";

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
        CustomRoutine,
        BodyAnalysisRecord,
    ],
    migrations: ["src/infrastructure/postgres/migrations/*.ts"],
    subscribers: [],
});
