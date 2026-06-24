import { Entity, PrimaryGeneratedColumn, Column } from 'typeorm';

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

  @Column({ type: 'simple-array', nullable: true })
  puntos_fuertes_fisicos?: string[];

  @Column({ type: 'simple-array', nullable: true })
  areas_mejora_fisicas?: string[];

  @Column({ type: 'text', nullable: true })
  recomendaciones?: string;

  @Column({ type: 'jsonb', nullable: true })
  metricas_adicionales?: Record<string, unknown>;

  @Column({ type: 'text', nullable: true })
  notas_adicionales?: string;

  @Column({ type: 'text', nullable: true })
  comparacion_progreso?: string;
}
