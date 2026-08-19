import { Entity, PrimaryGeneratedColumn, Column, OneToMany } from 'typeorm';
import { PhysiquePhoto } from './physique_photo.entity';

@Entity('Analisis_Fisico_Records')
export class BodyAnalysisRecord {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_id' })
  userId: string;

  @Column({ type: 'timestamp', default: () => 'CURRENT_TIMESTAMP' })
  fecha_analisis: Date;

  @Column({ type: 'text' })
  analisis_general: string;

  @Column({ type: 'decimal', precision: 5, scale: 2, nullable: true })
  peso_estimado_kg?: number;

  @Column({ type: 'decimal', precision: 5, scale: 2, nullable: true })
  porcentaje_grasa_estimado?: number;

  @Column({ type: 'decimal', precision: 5, scale: 2, nullable: true })
  masa_muscular_estimada_kg?: number;

  @Column({ type: 'varchar', length: 50, nullable: true })
  somatotipo_estimado?: string;

  @Column({ type: 'varchar', length: 50, nullable: true })
  nivel_fitness_estimado?: string;

  // jsonb y no `simple-array`: este último serializa a un CSV, y estas dos
  // guardan frases redactadas por la IA — con una coma dentro volvían partidas
  // en varios elementos.
  @Column({ type: 'jsonb', nullable: true })
  puntos_fuertes_fisicos?: string[];

  @Column({ type: 'jsonb', nullable: true })
  areas_mejora_fisicas?: string[];

  @Column({ type: 'text', nullable: true })
  recomendaciones?: string;

  @Column({ type: 'jsonb', nullable: true })
  metricas_adicionales?: Record<string, unknown>;

  @Column({ type: 'text', nullable: true })
  notas_adicionales?: string;

  @Column({ type: 'text', nullable: true })
  comparacion_progreso?: string;

  // ===== Seguimiento por fotos (apartado "Físico") =====

  /// 'chat' (análisis pedido dentro de Pulso) | 'seguimiento_fotos' (subida
  /// desde el apartado de físico). Permite separar el historial estructurado
  /// del ruido de análisis puntuales pedidos por chat.
  @Column({ type: 'varchar', length: 30, default: 'chat' })
  origen: string;

  @Column({ type: 'int', default: 0 })
  num_fotos: number;

  @Column({ type: 'simple-array', nullable: true })
  angulos_fotos?: string[];

  /// Grupos musculares por detrás del resto. Es EL dato que hace que la rutina
  /// generada priorice unos ejercicios sobre otros.
  @Column({ type: 'simple-array', nullable: true })
  grupos_musculares_retrasados?: string[];

  @Column({ type: 'simple-array', nullable: true })
  grupos_musculares_dominantes?: string[];

  /// Proporciones estimadas a ojo/pose (ratio hombro-cintura, simetría…).
  @Column({ type: 'jsonb', nullable: true })
  medidas_estimadas?: Record<string, unknown>;

  @Column({ type: 'text', nullable: true })
  postura_observaciones?: string;

  /// Una frase accionable: en qué se tiene que centrar el entrenamiento ahora.
  @Column({ type: 'text', nullable: true })
  prioridad_entrenamiento?: string;

  /// Normas de composición corporal y demás fuentes usadas para clasificar.
  @Column({ type: 'jsonb', nullable: true })
  fuentes_consultadas?: Record<string, unknown>[];

  @OneToMany(() => PhysiquePhoto, (foto) => foto.record)
  fotos: PhysiquePhoto[];
}
