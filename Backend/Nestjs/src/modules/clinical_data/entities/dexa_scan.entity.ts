import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
} from 'typeorm';

/// Una medición de composición corporal. Nació como "densitometría DEXA" y la
/// tabla conserva ese nombre, pero guarda cualquier medición del mismo tipo:
/// DEXA, bioimpedancia, plicometría o una báscula de casa. El `metodo` es lo
/// que dice cuánto fiarse de la cifra, no la tabla en la que está.
///
/// **Todo es opcional menos la fecha.** Es deliberado: una báscula da peso y
/// porcentaje de grasa y nada más; un DEXA da diez campos. Exigirlos todos
/// obligaba a inventarse los que faltan, que es peor que no tenerlos. Los
/// mínimos de verdad (peso y altura) viven en `Usuarios`, no aquí.
@Entity('Densitometrias_DEXA')
export class DexaScan {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column('uuid', { name: 'user_id' })
  userId: string;

  @Column({ type: 'date' })
  fecha_escaneo: Date;

  /// Cuándo se guardó la fila. Desempata `fecha_escaneo`, que es un `date` sin
  /// hora: dos mediciones del mismo día empataban y "la última" salía a suertes.
  /// Ordenar siempre por (fecha_escaneo, fecha_registro), nunca solo por la
  /// primera.
  @CreateDateColumn({ type: 'timestamp' })
  fecha_registro: Date;

  /// dexa | bioimpedancia | plicometria | bascula | otro. Determina la fiabilidad
  /// con la que la IA debe tratar el resto de la fila.
  @Column({ type: 'varchar', length: 30, default: 'dexa' })
  metodo: string;

  // ---- Lo esencial ----
  @Column({ type: 'decimal', precision: 6, scale: 2, nullable: true })
  peso_kg: number | null;

  /// Derivado del peso de esta medición y la altura del usuario. Se guarda
  /// calculado para que el histórico no cambie si luego se corrige la altura.
  @Column({ type: 'decimal', precision: 5, scale: 2, nullable: true })
  imc: number | null;

  @Column({ type: 'decimal', precision: 5, scale: 2, nullable: true })
  porcentaje_grasa: number | null;

  @Column({ type: 'decimal', precision: 6, scale: 2, nullable: true })
  masa_grasa_kg: number | null;

  /// Todo lo que no es grasa (músculo + hueso + agua + vísceras).
  @Column({ type: 'decimal', precision: 6, scale: 2, nullable: true })
  masa_magra_kg: number | null;

  /// Masa muscular esquelética. Un DEXA la distingue de la magra total; una
  /// báscula normalmente no, y entonces este campo se queda vacío.
  @Column({ type: 'decimal', precision: 8, scale: 2, nullable: true })
  masa_muscular_kg: number | null;

  /// Masa muscular como porcentaje del peso. Las básculas de bioimpedancia lo
  /// imprimen junto a los kg ("frecuencia muscular" en Fitdays).
  @Column({ type: 'decimal', precision: 5, scale: 2, nullable: true })
  musculo_pct: number | null;

  /// Porcentaje de músculo esquelético. NO es lo mismo que `musculo_pct`: la
  /// masa muscular total incluye músculo liso y cardíaco, así que sale más
  /// alta. Se guardan las dos porque el aparato da las dos.
  @Column({ type: 'decimal', precision: 5, scale: 2, nullable: true })
  musculo_esqueletico_pct: number | null;

  // ---- Detalle que solo trae un DEXA o una báscula buena ----
  @Column({ type: 'decimal', precision: 5, scale: 2, nullable: true })
  masa_osea_kg: number | null;

  @Column({ type: 'decimal', precision: 6, scale: 3, nullable: true })
  densidad_osea: number | null;

  @Column({ type: 'decimal', precision: 6, scale: 2, nullable: true })
  proteina_kg: number | null;

  @Column({ type: 'decimal', precision: 5, scale: 2, nullable: true })
  proteina_pct: number | null;

  @Column({ type: 'decimal', precision: 6, scale: 2, nullable: true })
  agua_corporal_kg: number | null;

  @Column({ type: 'decimal', precision: 5, scale: 2, nullable: true })
  agua_corporal_pct: number | null;

  @Column({ type: 'decimal', precision: 5, scale: 2, nullable: true })
  grasa_subcutanea_pct: number | null;

  /// Nivel/índice de grasa visceral tal y como lo imprima el aparato: la escala
  /// depende del fabricante, así que se guarda el número crudo sin convertir.
  @Column({ type: 'decimal', precision: 6, scale: 2, nullable: true })
  grasa_visceral: number | null;

  @Column({ type: 'int', nullable: true })
  tmb_kcal: number | null;

  /// Edad metabólica que estima el aparato. Es marketing con base fisiológica
  /// (sale del TMB), no una medida: se guarda porque el usuario la ve en su
  /// informe y va a preguntar por ella, no para tomar decisiones con ella.
  @Column({ type: 'int', nullable: true })
  edad_corporal: number | null;

  /// Peso "estándar" que propone el aparato para esa estatura. Referencia del
  /// fabricante, no un objetivo: cada marca usa su propia fórmula.
  @Column({ type: 'decimal', precision: 6, scale: 2, nullable: true })
  peso_ideal_kg: number | null;

  /// Índice de masa libre de grasa. Derivado de masa magra y altura: dice
  /// cuánto músculo hay *para esa estatura*, que es lo que decide si el margen
  /// de crecimiento es real o el usuario ya está cerca de su techo natural.
  @Column({ type: 'decimal', precision: 5, scale: 2, nullable: true })
  ffmi: number | null;

  @Column({ type: 'text', nullable: true })
  notas: string | null;
}
