"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.AppDataSource = void 0;
require("dotenv/config");
require("reflect-metadata");
const typeorm_1 = require("typeorm");
const user_entity_1 = require("../../modules/identity/entities/user.entity");
const nutrition_log_entity_1 = require("../../modules/nutrition/entities/nutrition_log.entity");
const subscription_entity_1 = require("../../modules/billing/entities/subscription.entity");
const posture_evaluation_entity_1 = require("../../modules/physical_analysis/entities/posture_evaluation.entity");
const dexa_scan_entity_1 = require("../../modules/clinical_data/entities/dexa_scan.entity");
const training_session_entity_1 = require("../../modules/training_sessions/entities/training_session.entity");
const user_profile_entity_1 = require("../../modules/user_profile/entities/user_profile.entity");
const custom_routine_entity_1 = require("../../modules/custom_routine/entities/custom_routine.entity");
const body_analysis_record_entity_1 = require("../../modules/body_analysis/entities/body_analysis_record.entity");
exports.AppDataSource = new typeorm_1.DataSource({
    type: "postgres",
    host: process.env.DB_HOST || "localhost",
    port: parseInt(process.env.DB_PORT || "5435"),
    username: process.env.DB_USERNAME,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_DATABASE,
    synchronize: false,
    logging: true,
    entities: [
        user_entity_1.User,
        nutrition_log_entity_1.NutritionLog,
        subscription_entity_1.Subscription,
        posture_evaluation_entity_1.PostureEvaluation,
        dexa_scan_entity_1.DexaScan,
        training_session_entity_1.TrainingSession,
        user_profile_entity_1.UserProfile,
        custom_routine_entity_1.CustomRoutine,
        body_analysis_record_entity_1.BodyAnalysisRecord,
    ],
    migrations: ["src/infrastructure/postgres/migrations/*.ts"],
    subscribers: [],
});
