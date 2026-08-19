import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Between, LessThanOrEqual, MoreThanOrEqual, Repository } from 'typeorm';
import { NutritionLog } from '../entities/nutrition_log.entity';
import { CreateNutritionLogDto } from '../dto/create-nutrition-log.dto';
import { UpdateNutritionLogDto } from '../dto/update-nutrition-log.dto';
import { UserProfile } from '../../user_profile/entities/user_profile.entity';
import { User } from '../../identity/entities/user.entity';

interface CalendarDayDto {
  fecha: string;
  totalKcal: number;
  targetKcal: number;
  status: 'done' | 'over' | 'rest' | 'future';
}

interface MacroTargets {
  kcal: number;
  proteinas_g: number;
  carbohidratos_g: number;
  grasas_g: number;
}

interface DayDetailDto {
  fecha: string;
  objetivo: MacroTargets;
  consumido: MacroTargets;
  meals: NutritionLog[];
}

@Injectable()
export class NutritionLogService {
  constructor(
    @InjectRepository(NutritionLog)
    private readonly nutritionLogRepository: Repository<NutritionLog>,
    @InjectRepository(UserProfile)
    private readonly profileRepository: Repository<UserProfile>,
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
  ) {}

  /** Mismo cálculo de objetivos que daily_summary.service.ts::getDailySummary —
   * perfil si tiene metas explícitas, si no la misma fórmula por peso corporal
   * (35 kcal/kg, 1.8 g prot/kg, 1 g grasa/kg, carbs por diferencia). */
  private async targetsForUser(userId: string): Promise<MacroTargets> {
    const [user, profile] = await Promise.all([
      this.userRepository.findOne({ where: { id: userId } }),
      this.profileRepository.findOne({ where: { user_id: userId } }),
    ]);

    if (
      profile?.meta_kcal != null &&
      profile?.meta_proteinas_g != null &&
      profile?.meta_carbohidratos_g != null &&
      profile?.meta_grasas_g != null
    ) {
      return {
        kcal: Number(profile.meta_kcal),
        proteinas_g: Number(profile.meta_proteinas_g),
        carbohidratos_g: Number(profile.meta_carbohidratos_g),
        grasas_g: Number(profile.meta_grasas_g),
      };
    }

    const peso = Number(user?.peso_base_kg ?? 70);
    const kcal = Math.round(peso * 35);
    const proteinas_g = Math.round(peso * 1.8 * 10) / 10;
    const grasas_g = Math.round(peso * 1.0 * 10) / 10;
    const carbohidratos_g =
      Math.round(Math.max(0, (kcal - proteinas_g * 4 - grasas_g * 9) / 4) * 10) / 10;
    return { kcal, proteinas_g, carbohidratos_g, grasas_g };
  }

  async findDayDetail(userId: string, date: string): Promise<DayDetailDto> {
    const [meals, objetivo] = await Promise.all([
      this.findByUser(userId, date, date),
      this.targetsForUser(userId),
    ]);

    const consumido = meals.reduce<MacroTargets>(
      (acc, m) => ({
        kcal: acc.kcal + Number(m.calorias_consumidas),
        proteinas_g: acc.proteinas_g + Number(m.proteinas_g),
        carbohidratos_g: acc.carbohidratos_g + Number(m.carbohidratos_g),
        grasas_g: acc.grasas_g + Number(m.grasas_g),
      }),
      { kcal: 0, proteinas_g: 0, carbohidratos_g: 0, grasas_g: 0 },
    );

    return { fecha: date, objetivo, consumido, meals };
  }

  async findCalendarSummary(userId: string, from: string, to: string): Promise<CalendarDayDto[]> {
    const targetKcal = (await this.targetsForUser(userId)).kcal;

    // TO_CHAR en SQL en vez de `new Date(...).toISOString()` en JS: el driver de pg
    // devuelve las columnas `date` como Date en la zona horaria local del proceso, y
    // volver a pasarlas por `Date`/`toISOString()` las corre un día si el servidor no
    // está en UTC (verificado: una fila del día 15 aparecía agrupada bajo el 14).
    const rows = await this.nutritionLogRepository
      .createQueryBuilder('n')
      .select("TO_CHAR(n.fecha_registro, 'YYYY-MM-DD')", 'fecha')
      .addSelect('COALESCE(SUM(n.calorias_consumidas), 0)::int', 'totalKcal')
      .where('n.userId = :userId', { userId })
      .andWhere('n.fecha_registro BETWEEN :from AND :to', { from, to })
      .groupBy('n.fecha_registro')
      .getRawMany<{ fecha: string; totalKcal: number }>();

    const byDate = new Map(rows.map((r) => [r.fecha, Number(r.totalKcal)]));

    const todayStr = new Date().toISOString().slice(0, 10);
    const result: CalendarDayDto[] = [];
    const cursor = new Date(from);
    const end = new Date(to);
    while (cursor <= end) {
      const fecha = cursor.toISOString().slice(0, 10);
      const totalKcal = byDate.get(fecha) ?? 0;
      let status: CalendarDayDto['status'];
      if (fecha > todayStr) {
        status = 'future';
      } else if (totalKcal === 0) {
        status = 'rest';
      } else if (totalKcal > targetKcal) {
        status = 'over';
      } else {
        status = 'done';
      }
      result.push({ fecha, totalKcal, targetKcal, status });
      cursor.setDate(cursor.getDate() + 1);
    }
    return result;
  }

  async create(dto: CreateNutritionLogDto) {
    const entity = this.nutritionLogRepository.create({
      ...dto,
      fecha_registro: new Date(dto.fecha_registro),
    });
    return this.nutritionLogRepository.save(entity);
  }

  async findByUser(userId: string, startDate?: string, endDate?: string) {
    if (startDate && endDate) {
      return this.nutritionLogRepository.find({
        where: {
          userId,
          fecha_registro: Between(new Date(startDate), new Date(endDate)),
        },
        order: { fecha_registro: 'DESC' },
      });
    }

    if (startDate) {
      return this.nutritionLogRepository.find({
        where: {
          userId,
          fecha_registro: MoreThanOrEqual(new Date(startDate)),
        },
        order: { fecha_registro: 'DESC' },
      });
    }

    if (endDate) {
      return this.nutritionLogRepository.find({
        where: {
          userId,
          fecha_registro: LessThanOrEqual(new Date(endDate)),
        },
        order: { fecha_registro: 'DESC' },
      });
    }

    return this.nutritionLogRepository.find({
      where: { userId },
      order: { fecha_registro: 'DESC' },
    });
  }

  async findTodayByUser(userId: string) {
    const start = new Date();
    start.setHours(0, 0, 0, 0);

    const end = new Date(start);
    end.setDate(end.getDate() + 1);

    return this.nutritionLogRepository.findOne({
      where: {
        userId,
        fecha_registro: Between(start, end),
      },
      order: { fecha_registro: 'DESC' },
    });
  }

  async findOne(id: string) {
    const nutritionLog = await this.nutritionLogRepository.findOne({ where: { id } });
    if (!nutritionLog) {
      throw new NotFoundException('Registro nutricional no encontrado.');
    }
    return nutritionLog;
  }

  async update(id: string, dto: UpdateNutritionLogDto) {
    await this.findOne(id);
    await this.nutritionLogRepository.update(id, {
      ...dto,
      fecha_registro: dto.fecha_registro ? new Date(dto.fecha_registro) : undefined,
    });
    return this.findOne(id);
  }

  async remove(id: string) {
    const nutritionLog = await this.findOne(id);
    await this.nutritionLogRepository.remove(nutritionLog);
    return { message: 'Registro nutricional eliminado correctamente.' };
  }
}
