import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ConfigModule } from '@nestjs/config';
import { User } from './modules/identity/entities/user.entity';
import { UserController } from './modules/identity/controller/user.controller';
import { UserService } from './modules/identity/service/user.service';
import { DexaScan } from './modules/clinical_data/entities/dexa_scan.entity';
import { DexaScanController } from './modules/clinical_data/controller/dexa_scan.controller';
import { DexaScanService } from './modules/clinical_data/service/dexa_scan.service';
import { PostureEvaluation } from './modules/physical_analysis/entities/posture_evaluation.entity';
import { PostureEvaluationController } from './modules/physical_analysis/controller/posture_evaluation.controller';
import { PostureEvaluationService } from './modules/physical_analysis/service/posture_evaluation.service';
import { NutritionLog } from './modules/nutrition/entities/nutrition_log.entity';
import { NutritionLogController } from './modules/nutrition/controller/nutrition_log.controller';
import { NutritionLogService } from './modules/nutrition/service/nutrition_log.service';
import { TrainingSession } from './modules/training_sessions/entities/training_session.entity';
import { TrainingSessionController } from './modules/training_sessions/controller/training_session.controller';
import { TrainingSessionService } from './modules/training_sessions/service/training_session.service';
import { CustomRoutine } from './modules/custom_routine/entities/custom_routine.entity';
import { CustomRoutineController } from './modules/custom_routine/controller/custom_routine.controller';
import { CustomRoutineService } from './modules/custom_routine/service/custom_routine.service';
import { BodyAnalysisRecord } from './modules/body_analysis/entities/body_analysis_record.entity';
import { BodyAnalysisController } from './modules/body_analysis/controller/body_analysis.controller';
import { BodyAnalysisService } from './modules/body_analysis/service/body_analysis.service';
import { Subscription } from './modules/billing/entities/subscription.entity';
import { SubscriptionController } from './modules/billing/controller/subscription.controller';
import { SubscriptionService } from './modules/billing/service/subscription.service';
import { UserProfile } from './modules/user_profile/entities/user_profile.entity';
import { UserProfileController } from './modules/user_profile/controller/user_profile.controller';
import { UserProfileService } from './modules/user_profile/service/user_profile.service';
import { AiController } from './modules/ai/controller/ai.controller';
import { AiService } from './modules/ai/service/ai.service';
import { Routine } from './modules/routine/entities/routine.entity';
import { RoutineDay } from './modules/routine/entities/routine_day.entity';
import { Exercise } from './modules/routine/entities/exercise.entity';
import { RoutineController } from './modules/routine/controller/routine.controller';
import { RoutineService } from './modules/routine/service/routine.service';

@Module({
  imports: [
    ConfigModule.forRoot(),
    TypeOrmModule.forRoot({
      type: 'postgres',
      host: process.env.DB_HOST,
      port: parseInt(process.env.DB_PORT || '5432', 10),
      username: process.env.DB_USERNAME,
      password: process.env.DB_PASSWORD,
      database: process.env.DB_DATABASE,
      entities: [User, DexaScan, PostureEvaluation, NutritionLog, TrainingSession, Subscription, UserProfile, CustomRoutine, BodyAnalysisRecord, Routine, RoutineDay, Exercise], 
      synchronize: false, 
    }),
    TypeOrmModule.forFeature([User, DexaScan, PostureEvaluation, NutritionLog, TrainingSession, Subscription, UserProfile, CustomRoutine, BodyAnalysisRecord, Routine, RoutineDay, Exercise]), 
  ],
  controllers: [
    UserController,
    DexaScanController,
    PostureEvaluationController,
    NutritionLogController,
    TrainingSessionController,
    SubscriptionController,
    UserProfileController,
    AiController,
    CustomRoutineController,
    BodyAnalysisController,
    RoutineController,
  ],
  providers: [
    UserService,
    DexaScanService,
    PostureEvaluationService,
    NutritionLogService,
    TrainingSessionService,
    SubscriptionService,
    UserProfileService,
    AiService,
    CustomRoutineService,
    BodyAnalysisService,
    RoutineService,
  ],
})
export class AppModule {}
