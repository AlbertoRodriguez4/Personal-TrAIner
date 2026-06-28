export class DailySummaryDto {
  kcal: number;
  proteinas_g: number;
  carbohidratos_g: number;
  grasas_g: number;
}

export class MacroCumplimientoDto {
  objetivo: number;
  consumido: number;
  porcentaje: number;
  cumplido: boolean;
}

export class UltimaSesionDto {
  id: string;
  fecha_programada: string;
  tipo_entrenamiento: string;
  estado: string;
  fecha_finalizacion: string | null;
}

export class DailySummaryResponseDto {
  usuario_id: string;
  fecha: string;
  objetivos: DailySummaryDto;
  consumido_hoy: DailySummaryDto;
  cumplimiento: {
    kcal: MacroCumplimientoDto;
    proteinas_g: MacroCumplimientoDto;
    carbohidratos_g: MacroCumplimientoDto;
    grasas_g: MacroCumplimientoDto;
  };
  objetivos_cumplidos: boolean;
  ultima_sesion: UltimaSesionDto | null;
  rutinas_count: number;
  metas_calculadas_automaticamente: boolean;
}