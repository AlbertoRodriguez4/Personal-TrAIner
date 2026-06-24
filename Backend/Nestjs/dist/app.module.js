"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.AppModule = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const config_1 = require("@nestjs/config");
const user_entity_1 = require("./modules/identity/entities/user.entity");
const user_controller_1 = require("./modules/identity/controller/user.controller");
const user_service_1 = require("./modules/identity/service/user.service");
const dexa_scan_entity_1 = require("./modules/clinical_data/entities/dexa_scan.entity");
const dexa_scan_controller_1 = require("./modules/clinical_data/controller/dexa_scan.controller");
const dexa_scan_service_1 = require("./modules/clinical_data/service/dexa_scan.service");
const posture_evaluation_entity_1 = require("./modules/physical_analysis/entities/posture_evaluation.entity");
const posture_evaluation_controller_1 = require("./modules/physical_analysis/controller/posture_evaluation.controller");
const posture_evaluation_service_1 = require("./modules/physical_analysis/service/posture_evaluation.service");
const nutrition_log_entity_1 = require("./modules/nutrition/entities/nutrition_log.entity");
const nutrition_log_controller_1 = require("./modules/nutrition/controller/nutrition_log.controller");
const nutrition_log_service_1 = require("./modules/nutrition/service/nutrition_log.service");
const training_session_entity_1 = require("./modules/training_sessions/entities/training_session.entity");
const training_session_controller_1 = require("./modules/training_sessions/controller/training_session.controller");
const training_session_service_1 = require("./modules/training_sessions/service/training_session.service");
const custom_routine_entity_1 = require("./modules/custom_routine/entities/custom_routine.entity");
const custom_routine_controller_1 = require("./modules/custom_routine/controller/custom_routine.controller");
const custom_routine_service_1 = require("./modules/custom_routine/service/custom_routine.service");
const body_analysis_record_entity_1 = require("./modules/body_analysis/entities/body_analysis_record.entity");
const body_analysis_controller_1 = require("./modules/body_analysis/controller/body_analysis.controller");
const body_analysis_service_1 = require("./modules/body_analysis/service/body_analysis.service");
const subscription_entity_1 = require("./modules/billing/entities/subscription.entity");
const subscription_controller_1 = require("./modules/billing/controller/subscription.controller");
const subscription_service_1 = require("./modules/billing/service/subscription.service");
const user_profile_entity_1 = require("./modules/user_profile/entities/user_profile.entity");
const user_profile_controller_1 = require("./modules/user_profile/controller/user_profile.controller");
const user_profile_service_1 = require("./modules/user_profile/service/user_profile.service");
const ai_controller_1 = require("./modules/ai/controller/ai.controller");
const ai_service_1 = require("./modules/ai/service/ai.service");
const routine_entity_1 = require("./modules/routine/entities/routine.entity");
const routine_day_entity_1 = require("./modules/routine/entities/routine_day.entity");
const exercise_entity_1 = require("./modules/routine/entities/exercise.entity");
const routine_controller_1 = require("./modules/routine/controller/routine.controller");
const routine_service_1 = require("./modules/routine/service/routine.service");
let AppModule = class AppModule {
};
exports.AppModule = AppModule;
exports.AppModule = AppModule = __decorate([
    (0, common_1.Module)({
        imports: [
            config_1.ConfigModule.forRoot(),
            typeorm_1.TypeOrmModule.forRoot({
                type: 'postgres',
                host: process.env.DB_HOST,
                port: parseInt(process.env.DB_PORT || '5432', 10),
                username: process.env.DB_USERNAME,
                password: process.env.DB_PASSWORD,
                database: process.env.DB_DATABASE,
                entities: [user_entity_1.User, dexa_scan_entity_1.DexaScan, posture_evaluation_entity_1.PostureEvaluation, nutrition_log_entity_1.NutritionLog, training_session_entity_1.TrainingSession, subscription_entity_1.Subscription, user_profile_entity_1.UserProfile, custom_routine_entity_1.CustomRoutine, body_analysis_record_entity_1.BodyAnalysisRecord, routine_entity_1.Routine, routine_day_entity_1.RoutineDay, exercise_entity_1.Exercise],
                synchronize: false,
            }),
            typeorm_1.TypeOrmModule.forFeature([user_entity_1.User, dexa_scan_entity_1.DexaScan, posture_evaluation_entity_1.PostureEvaluation, nutrition_log_entity_1.NutritionLog, training_session_entity_1.TrainingSession, subscription_entity_1.Subscription, user_profile_entity_1.UserProfile, custom_routine_entity_1.CustomRoutine, body_analysis_record_entity_1.BodyAnalysisRecord, routine_entity_1.Routine, routine_day_entity_1.RoutineDay, exercise_entity_1.Exercise]),
        ],
        controllers: [
            user_controller_1.UserController,
            dexa_scan_controller_1.DexaScanController,
            posture_evaluation_controller_1.PostureEvaluationController,
            nutrition_log_controller_1.NutritionLogController,
            training_session_controller_1.TrainingSessionController,
            subscription_controller_1.SubscriptionController,
            user_profile_controller_1.UserProfileController,
            ai_controller_1.AiController,
            custom_routine_controller_1.CustomRoutineController,
            body_analysis_controller_1.BodyAnalysisController,
            routine_controller_1.RoutineController,
        ],
        providers: [
            user_service_1.UserService,
            dexa_scan_service_1.DexaScanService,
            posture_evaluation_service_1.PostureEvaluationService,
            nutrition_log_service_1.NutritionLogService,
            training_session_service_1.TrainingSessionService,
            subscription_service_1.SubscriptionService,
            user_profile_service_1.UserProfileService,
            ai_service_1.AiService,
            custom_routine_service_1.CustomRoutineService,
            body_analysis_service_1.BodyAnalysisService,
            routine_service_1.RoutineService,
        ],
    })
], AppModule);
