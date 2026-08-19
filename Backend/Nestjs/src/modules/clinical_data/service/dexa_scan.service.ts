import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { DexaScan } from '../entities/dexa_scan.entity';
import { User } from '../../identity/entities/user.entity';
import { CreateDexaScanDto } from '../dto/create-dexa-scan.dto';
import { UpdateDexaScanDto } from '../dto/update-dexa-scan.dto';

/// Mediciones de composición corporal.
///
/// El servicio hace una cosa que no es evidente: **completa los campos que se
/// deducen de los demás**. Un DEXA imprime kg de grasa y kg de magra; una
/// báscula da peso y porcentaje. Son la misma información expresada distinto, y
/// si cada fila guardase solo lo que venía impreso, la IA vería un histórico
/// lleno de huecos y compararía peras con manzanas al mirar la evolución.
/// Derivar aquí (y no en el cliente ni en el prompt) deja una única definición
/// de cada magnitud y un histórico homogéneo.
@Injectable()
export class DexaScanService {
  constructor(
    @InjectRepository(DexaScan)
    private readonly dexaScanRepository: Repository<DexaScan>,
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
  ) {}

  private num(value: unknown): number | null {
    if (value === null || value === undefined || value === '') return null;
    const parsed = Number(value);
    return Number.isNaN(parsed) ? null : parsed;
  }

  private redondear(valor: number | null, decimales: number): number | null {
    if (valor === null || !Number.isFinite(valor)) return null;
    const factor = 10 ** decimales;
    return Math.round(valor * factor) / factor;
  }

  /// Completa el par kg ↔ % de una misma magnitud. Los aparatos imprimen unas
  /// veces una cosa y otras la otra, y guardar solo lo impreso deja el histórico
  /// comparando kg con porcentajes.
  private completarParKgPct(
    kg: number | null,
    pct: number | null,
    peso: number | null,
  ): [number | null, number | null] {
    if (peso === null || peso <= 0) return [kg, pct];
    if (kg === null && pct !== null) return [(peso * pct) / 100, pct];
    if (pct === null && kg !== null) return [kg, (kg / peso) * 100];
    return [kg, pct];
  }

  /// Rellena los huecos deducibles. Nunca pisa un valor que venga en el DTO: si
  /// el aparato lo midió, su cifra manda sobre la nuestra.
  private derivar(
    datos: Partial<DexaScan>,
    alturaCm: number | null,
  ): Partial<DexaScan> {
    let peso = this.num(datos.peso_kg);
    let grasaPct = this.num(datos.porcentaje_grasa);
    let masaGrasa = this.num(datos.masa_grasa_kg);
    let masaMagra = this.num(datos.masa_magra_kg);
    const alturaM = alturaCm && alturaCm > 0 ? alturaCm / 100 : null;

    // Peso primero: los demás cálculos dependen de él.
    if (peso === null && masaGrasa !== null && masaMagra !== null) {
      peso = masaGrasa + masaMagra;
    }
    [masaGrasa, grasaPct] = this.completarParKgPct(masaGrasa, grasaPct, peso);
    if (masaMagra === null && peso !== null && masaGrasa !== null) {
      masaMagra = peso - masaGrasa;
    }

    const [masaMuscular, musculoPct] = this.completarParKgPct(
      this.num(datos.masa_muscular_kg),
      this.num(datos.musculo_pct),
      peso,
    );
    const [proteinaKg, proteinaPct] = this.completarParKgPct(
      this.num(datos.proteina_kg),
      this.num(datos.proteina_pct),
      peso,
    );
    const [aguaKg, aguaPct] = this.completarParKgPct(
      this.num(datos.agua_corporal_kg),
      this.num(datos.agua_corporal_pct),
      peso,
    );

    return {
      ...datos,
      peso_kg: this.redondear(peso, 2),
      porcentaje_grasa: this.redondear(grasaPct, 2),
      masa_grasa_kg: this.redondear(masaGrasa, 2),
      masa_magra_kg: this.redondear(masaMagra, 2),
      masa_muscular_kg: this.redondear(masaMuscular, 2),
      musculo_pct: this.redondear(musculoPct, 2),
      proteina_kg: this.redondear(proteinaKg, 2),
      proteina_pct: this.redondear(proteinaPct, 2),
      agua_corporal_kg: this.redondear(aguaKg, 2),
      agua_corporal_pct: this.redondear(aguaPct, 2),
      imc: alturaM && peso !== null ? this.redondear(peso / alturaM ** 2, 2) : null,
      ffmi:
        alturaM && masaMagra !== null
          ? this.redondear(masaMagra / alturaM ** 2, 2)
          : null,
    };
  }

  private async alturaDelUsuario(userId: string): Promise<number | null> {
    const user = await this.userRepository.findOne({ where: { id: userId } });
    return this.num(user?.estatura_base_cm);
  }

  async create(dto: CreateDexaScanDto) {
    const { userId, fecha_escaneo, ...metricas } = dto;
    const entity = this.dexaScanRepository.create({
      ...this.derivar(metricas, await this.alturaDelUsuario(userId)),
      userId,
      fecha_escaneo: new Date(fecha_escaneo),
      metodo: dto.metodo ?? 'dexa',
    });
    return this.dexaScanRepository.save(entity);
  }

  async findByUser(userId: string) {
    return this.dexaScanRepository.find({
      where: { userId },
      // `fecha_registro` desempata: `fecha_escaneo` es un `date` sin hora y dos
      // mediciones del mismo día dejaban el orden al arbitrio de Postgres.
      order: { fecha_escaneo: 'DESC', fecha_registro: 'DESC' },
    });
  }

  /// La última medición con datos, que es la que la app enseña arriba del todo.
  async findLatest(userId: string) {
    return this.dexaScanRepository.findOne({
      where: { userId },
      // `fecha_registro` desempata: `fecha_escaneo` es un `date` sin hora y dos
      // mediciones del mismo día dejaban el orden al arbitrio de Postgres.
      order: { fecha_escaneo: 'DESC', fecha_registro: 'DESC' },
    });
  }

  /// Sin capa de sesión, la pertenencia se comprueba a mano comparando el
  /// `userId` que manda el cliente con el de la fila (mismo patrón que
  /// `routine` y `nutrition`).
  async findOne(id: string, userId: string) {
    const dexaScan = await this.dexaScanRepository.findOne({ where: { id } });
    if (!dexaScan) {
      throw new NotFoundException('Medición de composición corporal no encontrada.');
    }
    if (dexaScan.userId !== userId) {
      throw new ForbiddenException('Esta medición no pertenece al usuario indicado.');
    }
    return dexaScan;
  }

  async update(id: string, userId: string, dto: UpdateDexaScanDto) {
    const actual = await this.findOne(id, userId);
    const { fecha_escaneo, ...metricas } = dto;

    // Se derivan los campos sobre la fila ya fusionada, no solo sobre el parche:
    // corregir el peso de una medición tiene que recalcular su IMC y su FFMI.
    // Fuera `id`/`userId`/`fecha_escaneo`: son la identidad de la fila, no
    // métricas, y no deben viajar dentro del payload de `update`.
    const {
      id: _id,
      userId: _userId,
      fecha_escaneo: _fecha,
      ...fusionado
    } = { ...actual, ...metricas };

    await this.dexaScanRepository.update(id, {
      ...this.derivar(fusionado, await this.alturaDelUsuario(userId)),
      fecha_escaneo: fecha_escaneo ? new Date(fecha_escaneo) : actual.fecha_escaneo,
    });
    return this.findOne(id, userId);
  }

  async remove(id: string, userId: string) {
    const dexaScan = await this.findOne(id, userId);
    await this.dexaScanRepository.remove(dexaScan);
    return { message: 'Medición de composición corporal eliminada correctamente.' };
  }
}
