import { Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ConfigModule } from '@nestjs/config';
import { AuthModule } from './modules/auth/auth.module';
import { JwtAuthGuard } from './modules/auth/jwt-auth.guard';
import { User } from './modules/identity/entities/user.entity';
import { UserController } from './modules/identity/controller/user.controller';
import { UserService } from './modules/identity/service/user.service';
import { DexaScan } from './modules/clinical_data/entities/dexa_scan.entity';
import { DexaScanController } from './modules/clinical_data/controller/dexa_scan.controller';
import { DexaScanService } from './modules/clinical_data/service/dexa_scan.service';
import { ClinicalReport } from './modules/clinical_data/entities/clinical_report.entity';
import { ClinicalMarker } from './modules/clinical_data/entities/clinical_marker.entity';
import { ClinicalReportController } from './modules/clinical_data/controller/clinical_report.controller';
import { ClinicalReportService } from './modules/clinical_data/service/clinical_report.service';
import { PostureEvaluation } from './modules/physical_analysis/entities/posture_evaluation.entity';
import { PostureEvaluationController } from './modules/physical_analysis/controller/posture_evaluation.controller';
import { PostureEvaluationService } from './modules/physical_analysis/service/posture_evaluation.service';
import { NutritionLog } from './modules/nutrition/entities/nutrition_log.entity';
import { NutritionLogController } from './modules/nutrition/controller/nutrition_log.controller';
import { NutritionLogService } from './modules/nutrition/service/nutrition_log.service';
import { TrainingSession } from './modules/training_sessions/entities/training_session.entity';
import { TrainingSessionController } from './modules/training_sessions/controller/training_session.controller';
import { TrainingSessionService } from './modules/training_sessions/service/training_session.service';
import { BodyAnalysisRecord } from './modules/body_analysis/entities/body_analysis_record.entity';
import { BodyAnalysisController } from './modules/body_analysis/controller/body_analysis.controller';
import { BodyAnalysisService } from './modules/body_analysis/service/body_analysis.service';
import { PhysiquePhoto } from './modules/body_analysis/entities/physique_photo.entity';
import { PhysiquePhotoService } from './modules/body_analysis/service/physique_photo.service';
import { AiContextController } from './modules/ai_context/controller/ai_context.controller';
import { AiContextService } from './modules/ai_context/service/ai_context.service';
import { Subscription } from './modules/billing/entities/subscription.entity';
import { SubscriptionController } from './modules/billing/controller/subscription.controller';
import { SubscriptionService } from './modules/billing/service/subscription.service';
import { UserProfile } from './modules/user_profile/entities/user_profile.entity';
import { UserProfileController } from './modules/user_profile/controller/user_profile.controller';
import { UserProfileService } from './modules/user_profile/service/user_profile.service';
import { AiController } from './modules/ai/controller/ai.controller';
import { AiService } from './modules/ai/service/ai.service';
import { TelemetryController } from './modules/telemetry/controller/telemetry.controller';
import { TelemetryService } from './modules/telemetry/service/telemetry.service';
import { Routine } from './modules/routine/entities/routine.entity';
import { RoutineDay } from './modules/routine/entities/routine_day.entity';
import { Exercise } from './modules/routine/entities/exercise.entity';
import { RoutineController } from './modules/routine/controller/routine.controller';
import { RoutineService } from './modules/routine/service/routine.service';
import { DailySummaryController } from './modules/daily_summary/controller/daily_summary.controller';
import { DailySummaryService } from './modules/daily_summary/service/daily_summary.service';
import { ExerciseCatalog } from './modules/exercises_catalog/entities/exercise_catalog.entity';
import { ExerciseCatalogController } from './modules/exercises_catalog/controller/exercise_catalog.controller';
import { ExerciseCatalogService } from './modules/exercises_catalog/service/exercise_catalog.service';
import { RecoveryLog } from './modules/recovery/entities/recovery_log.entity';
import { RecoveryController } from './modules/recovery/controller/recovery.controller';
import { RecoveryService } from './modules/recovery/service/recovery.service';
import { Supplement } from './modules/supplements/entities/supplement.entity';
import { SupplementLog } from './modules/supplements/entities/supplement_log.entity';
import { SupplementController } from './modules/supplements/controller/supplement.controller';
import { SupplementService } from './modules/supplements/service/supplement.service';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    AuthModule,
    TypeOrmModule.forRoot({
      type: 'postgres',
      host: process.env.DB_HOST,
      port: parseInt(process.env.DB_PORT || '5432', 10),
      username: process.env.DB_USERNAME,
      password: process.env.DB_PASSWORD,
      database: process.env.DB_DATABASE,
      entities: [User, DexaScan, PostureEvaluation, NutritionLog, TrainingSession, Subscription, UserProfile, BodyAnalysisRecord, Routine, RoutineDay, Exercise, ExerciseCatalog, RecoveryLog, Supplement, SupplementLog, ClinicalReport, ClinicalMarker, PhysiquePhoto],
      synchronize: false,
    }),
    TypeOrmModule.forFeature([User, DexaScan, PostureEvaluation, NutritionLog, TrainingSession, Subscription, UserProfile, BodyAnalysisRecord, Routine, RoutineDay, Exercise, ExerciseCatalog, RecoveryLog, Supplement, SupplementLog, ClinicalReport, ClinicalMarker, PhysiquePhoto]),
  ],
  controllers: [
    UserController,
    DexaScanController,
    ClinicalReportController,
    PostureEvaluationController,
    NutritionLogController,
    TrainingSessionController,
    SubscriptionController,
    UserProfileController,
    AiController,
    AiContextController,
    BodyAnalysisController,
    RoutineController,
    TelemetryController,
    DailySummaryController,
    ExerciseCatalogController,
    RecoveryController,
    SupplementController,
  ],
  providers: [
    // Guarda global: TODO endpoint exige token salvo los marcados con @Public().
    // Registrarla aquí y no controlador por controlador es deliberado — así una
    // ruta nueva nace protegida, en vez de quedar abierta si alguien olvida el
    // decorador.
    { provide: APP_GUARD, useClass: JwtAuthGuard },
    UserService,
    DexaScanService,
    ClinicalReportService,
    PostureEvaluationService,
    NutritionLogService,
    TrainingSessionService,
    SubscriptionService,
    UserProfileService,
    AiService,
    BodyAnalysisService,
    PhysiquePhotoService,
    AiContextService,
    RoutineService,
    TelemetryService,
    DailySummaryService,
    ExerciseCatalogService,
    RecoveryService,
    SupplementService,
  ],
})
export class AppModule {}
