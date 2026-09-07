export class ClinicalDocumentDto {
  userId: string;
  /// PDF/imagen en base64 (sin el prefijo `data:`).
  data: string;
  mimeType: string;
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
  userId: string;
  valores: ClinicalManualValueDto[];
  /// Fecha de la analítica (AAAA-MM-DD). Hoy si falta.
  fecha?: string;
}

/// Una medición de composición corporal tecleada a mano. Todo opcional menos el
/// usuario: cada aparato mide un subconjunto distinto, y el servicio de IA
/// deriva lo que se pueda deducir (IMC, masa grasa, masa magra, FFMI) de lo que
/// llegue en vez de exigir que el cliente rellene los huecos.
export class BodyCompositionDto {
  userId: string;
  /// Fecha de la medición (AAAA-MM-DD). Hoy si falta.
  fecha?: string;
  /// 'dexa' | 'bioimpedancia' | 'plicometria' | 'bascula' | 'otro'
  metodo?: string;
  pesoKg?: number;
  porcentajeGrasa?: number;
  masaMuscularKg?: number;
  musculoEsqueleticoPct?: number;
  masaOseaKg?: number;
  /// Densidad mineral ósea en g/cm².
  densidadOsea?: number;
  proteinaKg?: number;
  aguaCorporalKg?: number;
  aguaCorporalPct?: number;
  grasaSubcutaneaPct?: number;
  grasaVisceral?: number;
  tmbKcal?: number;
  edadCorporal?: number;
  pesoIdealKg?: number;
  notas?: string;
}

export class PhysiquePhotoDto {
  data: string;
  mimeType: string;
  /// 'frontal' | 'lateral' | 'espalda' | 'otro'
  angulo?: string;
}

export class PhysiqueAnalysisDto {
  userId: string;
  photos: PhysiquePhotoDto[];
  /// Contexto libre que escriba el usuario ("vengo de 8 semanas de déficit").
  notas?: string;
}

/// Registro manual de comida (nutricion, sin foto): nombre + cantidad, en
/// gramos o en una referencia corporal/de plato. Solo uno de los dos campos
/// de cantidad viaja según qué pestaña esté activa en la app.
export class FoodEstimateDto {
  userId: string;
  nombreAlimento: string;
  cantidadG?: number;
  /// 'palma' | 'puno' | 'punado' | 'pulgar' | 'vaso' | 'botella' | 'cuarto_plato' | 'media_plato' | 'plato_completo'
  referenciaUnidad?: string;
  referenciaCantidad?: number;
}

/// Autocompletado del catálogo local de alimentos mientras el usuario escribe.
export class FoodSuggestionsDto {
  query: string;
}

/// Un ingrediente dentro de un plato compuesto. Igual que FoodEstimateDto pero
/// sin userId: el usuario es del plato entero, no de cada tomate.
export class IngredientePlatoDto {
  nombreAlimento: string;
  cantidadG?: number;
  referenciaUnidad?: string;
  referenciaCantidad?: number;
}

/// Plato compuesto: varios ingredientes que se suman en UNA entrada del diario.
///
/// Comer no es comer un alimento: es "ensalada de garbanzos con atun, tomate,
/// lechuga y un chorro de aceite". Registrandolo de uno en uno son cinco
/// entradas y cinco busquedas, y lo que pasa de verdad es que no se registra.
export class MealEstimateDto {
  userId: string;
  ingredientes: IngredientePlatoDto[];
}

/// Que referencias corporales (palma, puno, punado...) tienen sentido para un
/// alimento. Se consultan en vez de duplicar la tabla en la app, que acabaria
/// desincronizada con la del backend.
export class FoodReferencesDto {
  userId: string;
  nombreAlimento: string;
}
