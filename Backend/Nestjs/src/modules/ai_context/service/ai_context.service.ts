import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from '../../identity/entities/user.entity';
import { UserProfile } from '../../user_profile/entities/user_profile.entity';
import { DexaScan } from '../../clinical_data/entities/dexa_scan.entity';
import { ClinicalReportService } from '../../clinical_data/service/clinical_report.service';
import { PhysiquePhotoService } from '../../body_analysis/service/physique_photo.service';

/// Perfil consolidado que Pulso lee en CADA turno, de cualquier modo.
///
/// Existe como un único endpoint (en vez de que Python vaya pidiendo trozos a
/// cuatro rutas distintas) por dos motivos: una sola llamada por turno de chat,
/// y un solo sitio donde se decide qué se considera "datos suficientes" — el
/// flag `completitud`, que es lo que hace que la IA pida al usuario rellenar
/// sus datos antes de seguir en vez de inventarse un perfil.
///
/// El eje es la **composición corporal**: peso, IMC, grasa y masa magra son lo
/// que decide calorías, macros y prioridades de entrenamiento, y son medidas,
/// no estimadas. Las fotos y las analíticas matizan; no sustituyen.
@Injectable()
export class AiContextService {
  /// Cuántas mediciones anteriores se devuelven para ver la tendencia. Cuatro
  /// llegan para leer una dirección sin engordar el prompt (cada una son ~15
  /// tokens y los modos de texto van a Groq con 8000 TPM).
  private static readonly MAX_HISTORICO_COMPOSICION = 4;

  constructor(
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    @InjectRepository(UserProfile)
    private readonly profileRepository: Repository<UserProfile>,
    @InjectRepository(DexaScan)
    private readonly dexaRepository: Repository<DexaScan>,
    private readonly clinicalReportService: ClinicalReportService,
    private readonly physiquePhotoService: PhysiquePhotoService,
  ) {}

  private edad(fechaNacimiento?: Date | null): number | null {
    if (!fechaNacimiento) return null;
    const nacimiento = new Date(fechaNacimiento);
    if (Number.isNaN(nacimiento.getTime())) return null;
    const hoy = new Date();
    let edad = hoy.getFullYear() - nacimiento.getFullYear();
    const mes = hoy.getMonth() - nacimiento.getMonth();
    if (mes < 0 || (mes === 0 && hoy.getDate() < nacimiento.getDate())) {
      edad -= 1;
    }
    return edad;
  }

  private num(value: unknown): number | null {
    if (value === null || value === undefined || value === '') return null;
    const parsed = Number(value);
    return Number.isNaN(parsed) ? null : parsed;
  }

  private fecha(valor: Date | string | null | undefined): string | null {
    if (!valor) return null;
    return typeof valor === 'string'
      ? valor.slice(0, 10)
      : valor.toISOString().slice(0, 10);
  }

  private medicion(scan: DexaScan) {
    return {
      fecha: this.fecha(scan.fecha_escaneo),
      metodo: scan.metodo ?? 'dexa',
      peso_kg: this.num(scan.peso_kg),
      imc: this.num(scan.imc),
      porcentaje_grasa: this.num(scan.porcentaje_grasa),
      masa_grasa_kg: this.num(scan.masa_grasa_kg),
      masa_magra_kg: this.num(scan.masa_magra_kg),
      masa_muscular_kg: this.num(scan.masa_muscular_kg),
      musculo_pct: this.num(scan.musculo_pct),
      musculo_esqueletico_pct: this.num(scan.musculo_esqueletico_pct),
      masa_osea_kg: this.num(scan.masa_osea_kg),
      densidad_osea: this.num(scan.densidad_osea),
      proteina_kg: this.num(scan.proteina_kg),
      proteina_pct: this.num(scan.proteina_pct),
      agua_corporal_kg: this.num(scan.agua_corporal_kg),
      agua_corporal_pct: this.num(scan.agua_corporal_pct),
      grasa_subcutanea_pct: this.num(scan.grasa_subcutanea_pct),
      grasa_visceral: this.num(scan.grasa_visceral),
      tmb_kcal: this.num(scan.tmb_kcal),
      edad_corporal: this.num(scan.edad_corporal),
      peso_ideal_kg: this.num(scan.peso_ideal_kg),
      ffmi: this.num(scan.ffmi),
    };
  }

  async build(userId: string) {
    const [user, profile, mediciones, clinico, fisico] = await Promise.all([
      this.userRepository.findOne({ where: { id: userId } }),
      this.profileRepository.findOne({ where: { user_id: userId } }),
      this.dexaRepository.find({
        where: { userId },
        // `fecha_registro` desempata: sin él, dos mediciones del mismo día
        // salían en orden arbitrario y la IA podía leer la corregida o la
        // original según le tocase.
        order: { fecha_escaneo: 'DESC', fecha_registro: 'DESC' },
        take: AiContextService.MAX_HISTORICO_COMPOSICION + 1,
      }),
      this.clinicalReportService.buildAiSummary(userId),
      this.physiquePhotoService.buildAiSummary(userId),
    ]);

    const actual = mediciones.length ? this.medicion(mediciones[0]) : null;
    const alturaCm = this.num(user?.estatura_base_cm);

    // El peso vigente es el de la última medición, no el que se tecleó al
    // registrarse: si el usuario se pesa cada semana, `peso_base_kg` envejece y
    // los macros calculados sobre él dejan de cuadrar. Se marca de dónde sale
    // para que la IA pueda decir "según tu última medición del X".
    const pesoMedido = actual?.peso_kg ?? null;
    const pesoPerfil = this.num(user?.peso_base_kg);
    const pesoVigente = pesoMedido ?? pesoPerfil;

    const datosBasicos = {
      edad: this.edad(user?.fecha_nacimiento),
      sexo: profile?.sexo ?? null,
      altura_cm: alturaCm,
      peso_kg: pesoVigente,
      peso_fuente: pesoMedido !== null ? 'medicion' : 'perfil',
      peso_fecha: pesoMedido !== null ? actual?.fecha : null,
      nivel_experiencia: profile?.nivel_experiencia ?? null,
      objetivos: profile?.objetivos ?? [],
      dias_entrenamiento_semana: profile?.dias_entrenamiento_semana ?? null,
      condiciones_medicas: profile?.condiciones_medicas ?? null,
      metas: {
        kcal: this.num(profile?.meta_kcal),
        proteinas_g: this.num(profile?.meta_proteinas_g),
        carbohidratos_g: this.num(profile?.meta_carbohidratos_g),
        grasas_g: this.num(profile?.meta_grasas_g),
      },
    };

    const composicion = {
      tiene_datos: actual !== null,
      actual,
      evolucion: mediciones
        .slice(1, AiContextService.MAX_HISTORICO_COMPOSICION + 1)
        .map((scan) => {
          const m = this.medicion(scan);
          return {
            fecha: m.fecha,
            peso_kg: m.peso_kg,
            porcentaje_grasa: m.porcentaje_grasa,
            masa_magra_kg: m.masa_magra_kg,
          };
        }),
    };

    // El mínimo real para no inventarse nada es peso y altura: sin eso no hay
    // gasto calórico ni macros que calcular, y todo lo demás sería un cuento.
    // El resto (composición, fotos, analítica, edad, sexo) afina la respuesta
    // pero no debe bloquear al usuario: se pide como recomendación, no como
    // requisito, porque un perfil a medias que responde vale más que uno
    // completo que nunca se rellena.
    const tieneMinimos =
      datosBasicos.altura_cm !== null && datosBasicos.peso_kg !== null;

    const faltantes: string[] = [];
    if (datosBasicos.altura_cm === null) faltantes.push('altura');
    if (datosBasicos.peso_kg === null) faltantes.push('peso');

    const recomendados: string[] = [];
    if (!composicion.tiene_datos)
      recomendados.push('composición corporal (% de grasa, masa muscular…)');
    if (!datosBasicos.sexo) recomendados.push('sexo');
    if (datosBasicos.edad === null) recomendados.push('fecha de nacimiento');
    if (!datosBasicos.nivel_experiencia) recomendados.push('nivel de experiencia');
    if (!fisico.tiene_datos) recomendados.push('análisis del físico con fotos');
    if (!clinico.tiene_datos) recomendados.push('analítica de sangre');

    return {
      user_id: userId,
      datos_basicos: datosBasicos,
      composicion,
      fisico,
      clinico,
      completitud: {
        suficiente_para_personalizar: tieneMinimos,
        tiene_minimos: tieneMinimos,
        tiene_composicion: composicion.tiene_datos,
        faltantes,
        recomendados,
      },
    };
  }
}
