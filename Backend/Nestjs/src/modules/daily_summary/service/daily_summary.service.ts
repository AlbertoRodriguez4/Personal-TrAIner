import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { UserProfile } from '../../user_profile/entities/user_profile.entity';
import { User } from '../../identity/entities/user.entity';
import { NutritionLog } from '../../nutrition/entities/nutrition_log.entity';
import { TrainingSession } from '../../training_sessions/entities/training_session.entity';
import { Routine } from '../../routine/entities/routine.entity';
import {
  DailySummaryResponseDto,
  DailySummaryDto,
  MacroCumplimientoDto,
  UltimaSesionDto,
} from '../dto/daily-summary.dto';

@Injectable()
export class DailySummaryService {
  constructor(
    @InjectRepository(UserProfile)
    private readonly profileRepo: Repository<UserProfile>,
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
    @InjectRepository(NutritionLog)
    private readonly nutritionRepo: Repository<NutritionLog>,
    @InjectRepository(TrainingSession)
    private readonly sessionRepo: Repository<TrainingSession>,
    @InjectRepository(Routine)
    private readonly routineRepo: Repository<Routine>,
  ) {}

  async getDailySummary(userId: string): Promise<DailySummaryResponseDto> {
    const user = await this.userRepo.findOne({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException(`Usuario ${userId} no encontrado`);
    }

    const profile = await this.profileRepo.findOne({
      where: { user_id: userId },
    });

    // 1) Objetivos: del perfil o calculados por fórmula fisiológica
    const peso = Number(user.peso_base_kg ?? 70);
    let objetivos: DailySummaryDto;
    let auto = false;

    if (
      profile?.meta_kcal != null &&
      profile?.meta_proteinas_g != null &&
      profile?.meta_carbohidratos_g != null &&
      profile?.meta_grasas_g != null
    ) {
      objetivos = {
        kcal: Number(profile.meta_kcal),
        proteinas_g: Number(profile.meta_proteinas_g),
        carbohidratos_g: Number(profile.meta_carbohidratos_g),
        grasas_g: Number(profile.meta_grasas_g),
      };
    } else {
      // Defaults: 35 kcal/kg, 1.8 g prot/kg, 4 g carb/kg, 1 g grasa/kg
      auto = true;
      const kcal = Math.round(peso * 35);
      const proteinas_g = Math.round(peso * 1.8 * 10) / 10;
      const grasas_g = Math.round(peso * 1.0 * 10) / 10;
      const carbohidratos_g = Math.round(
        Math.max(0, (kcal - proteinas_g * 4 - grasas_g * 9) / 4) * 10,
      ) / 10;
      objetivos = { kcal, proteinas_g, carbohidratos_g, grasas_g };
    }

    // 2) Consumido hoy: agregado de NutritionLog con fecha_registro = hoy
    const today = new Date();
    const todayStr = today.toISOString().slice(0, 10);

    const rows = await this.nutritionRepo
      .createQueryBuilder('n')
      .select([
        'COALESCE(SUM(n.calorias_consumidas),0)::float AS kcal',
        'COALESCE(SUM(n.proteinas_g),0)::float AS proteinas_g',
        'COALESCE(SUM(n.carbohidratos_g),0)::float AS carbohidratos_g',
        'COALESCE(SUM(n.grasas_g),0)::float AS grasas_g',
      ])
      .where('n.userId = :uid', { uid: userId })
      .andWhere("n.fecha_registro = :hoy", { hoy: todayStr })
      .getRawOne<{ kcal: string; proteinas_g: string; carbohidratos_g: string; grasas_g: string }>();

    const consumido: DailySummaryDto = {
      kcal: Number(rows?.kcal ?? 0),
      proteinas_g: Number(rows?.proteinas_g ?? 0),
      carbohidratos_g: Number(rows?.carbohidratos_g ?? 0),
      grasas_g: Number(rows?.grasas_g ?? 0),
    };

    // 3) Cumplimiento por macro
    const mk = (
      obj: number,
      con: number,
    ): MacroCumplimientoDto => {
      const objetivo = Number(obj) || 0;
      const pct = objetivo > 0 ? con / objetivo : 0;
      // Se considera cumplido si ha ingerido al menos el 95% del objetivo
      // de proteígenos/grasas y no se ha excedido más de un 15% en kcal.
      return {
        objetivo,
        consumido: con,
        porcentaje: Math.round(pct * 1000) / 10,
        cumplido: objetivo > 0 && pct >= 0.95,
      };
    };

    const cK = mk(objetivos.kcal, consumido.kcal);
    const cP = mk(objetivos.proteinas_g, consumido.proteinas_g);
    const cC = mk(objetivos.carbohidratos_g, consumido.carbohidratos_g);
    const cG = mk(objetivos.grasas_g, consumido.grasas_g);

    const objetivosCumplidos =
      cP.cumplido &&
      cG.cumplido &&
      consumido.kcal >= objetivos.kcal * 0.85 &&
      consumido.kcal <= objetivos.kcal * 1.15;

    // 4) Última sesión de entrenamiento
    const lastSession = await this.sessionRepo.findOne({
      where: { userId },
      order: { fecha_programada: 'DESC' },
    });

    let ultimaSesion: UltimaSesionDto | null = null;
    if (lastSession) {
      ultimaSesion = {
        id: lastSession.id,
        fecha_programada: lastSession.fecha_programada.toISOString(),
        tipo_entrenamiento: lastSession.tipo_entrenamiento,
        estado: lastSession.estado,
        fecha_finalizacion: lastSession.fecha_finalizacion
          ? lastSession.fecha_finalizacion.toISOString()
          : null,
      };
    }

    // 5) Conteo de rutinas del usuario
    const rutinasCount = await this.routineRepo.count();

    return {
      usuario_id: userId,
      fecha: todayStr,
      objetivos,
      consumido_hoy: consumido,
      cumplimiento: {
        kcal: cK,
        proteinas_g: cP,
        carbohidratos_g: cC,
        grasas_g: cG,
      },
      objetivos_cumplidos: objetivosCumplidos,
      ultima_sesion: ultimaSesion,
      rutinas_count: rutinasCount,
      metas_calculadas_automaticamente: auto,
    };
  }
}