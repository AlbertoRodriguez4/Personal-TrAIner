import { IsArray, IsNotEmpty, IsNumber, IsOptional, IsString } from 'class-validator';

// Cada campo lleva al menos un decorador porque el ValidationPipe global va con
// `whitelist`: lo que no esté declarado se descarta antes de llegar aquí. Las
// listas anidadas (`valores`, `photos`) se validan como listas y nada más:
// `AiService` copia solo los campos que Python lee, y Python ya valida cada
// elemento con su propio schema.

export class ClinicalDocumentDto {
  @IsString()
  @IsNotEmpty()
  userId: string;

  /// PDF/imagen en base64 (sin el prefijo `data:`).
  @IsString()
  @IsNotEmpty()
  data: string;

  @IsString()
  @IsNotEmpty()
  mimeType: string;

  @IsOptional()
  @IsString()
  fileName?: string;
}

export class ClinicalManualValueDto {
  /// Nombre o código del biomarcador; se normaliza en el servicio de IA.
  codigo: string;
  valor: number;
  unidad?: string;
  rango_min?: number;
  rango_max?: number;
}

export class ClinicalManualDto {
  @IsString()
  @IsNotEmpty()
  userId: string;

  @IsArray()
  valores: ClinicalManualValueDto[];

  /// Fecha de la analítica (AAAA-MM-DD). Hoy si falta.
  @IsOptional()
  @IsString()
  fecha?: string;
}

/// Una medición de composición corporal tecleada a mano. Todo opcional menos el
/// usuario: cada aparato mide un subconjunto distinto, y el servicio de IA
/// deriva lo que se pueda deducir (IMC, masa grasa, masa magra, FFMI) de lo que
/// llegue en vez de exigir que el cliente rellene los huecos.
export class BodyCompositionDto {
  @IsString()
  @IsNotEmpty()
  userId: string;

  /// Fecha de la medición (AAAA-MM-DD). Hoy si falta.
  @IsOptional()
  @IsString()
  fecha?: string;

  /// 'dexa' | 'bioimpedancia' | 'plicometria' | 'bascula' | 'otro'
  @IsOptional()
  @IsString()
  metodo?: string;

  @IsOptional()
  @IsNumber()
  pesoKg?: number;

  @IsOptional()
  @IsNumber()
  porcentajeGrasa?: number;

  @IsOptional()
  @IsNumber()
  masaMuscularKg?: number;

  @IsOptional()
  @IsNumber()
  musculoEsqueleticoPct?: number;

  @IsOptional()
  @IsNumber()
  masaOseaKg?: number;

  /// Densidad mineral ósea en g/cm².
  @IsOptional()
  @IsNumber()
  densidadOsea?: number;

  @IsOptional()
  @IsNumber()
  proteinaKg?: number;

  @IsOptional()
  @IsNumber()
  aguaCorporalKg?: number;

  @IsOptional()
  @IsNumber()
  aguaCorporalPct?: number;

  @IsOptional()
  @IsNumber()
  grasaSubcutaneaPct?: number;

  @IsOptional()
  @IsNumber()
  grasaVisceral?: number;

  @IsOptional()
  @IsNumber()
  tmbKcal?: number;

  @IsOptional()
  @IsNumber()
  edadCorporal?: number;

  @IsOptional()
  @IsNumber()
  pesoIdealKg?: number;

  @IsOptional()
  @IsString()
  notas?: string;
}

export class PhysiquePhotoDto {
  data: string;
  mimeType: string;
  /// 'frontal' | 'lateral' | 'espalda' | 'otro'
  angulo?: string;
}

export class PhysiqueAnalysisDto {
  @IsString()
  @IsNotEmpty()
  userId: string;

  @IsArray()
  photos: PhysiquePhotoDto[];

  /// Contexto libre que escriba el usuario ("vengo de 8 semanas de déficit").
  @IsOptional()
  @IsString()
  notas?: string;
}

/// Registro manual de comida (nutricion, sin foto): nombre + cantidad, en
/// gramos o en una referencia corporal/de plato. Solo uno de los dos campos
/// de cantidad viaja según qué pestaña esté activa en la app.
export class FoodEstimateDto {
  @IsString()
  @IsNotEmpty()
  userId: string;

  @IsString()
  @IsNotEmpty()
  nombreAlimento: string;

  @IsOptional()
  @IsNumber()
  cantidadG?: number;

  /// 'palma' | 'puno' | 'punado' | 'pulgar' | 'vaso' | 'botella' | 'cuarto_plato' | 'media_plato' | 'plato_completo'
  @IsOptional()
  @IsString()
  referenciaUnidad?: string;

  @IsOptional()
  @IsNumber()
  referenciaCantidad?: number;
}

/// Autocompletado del catálogo local de alimentos mientras el usuario escribe.
export class FoodSuggestionsDto {
  @IsString()
  query: string;
}
