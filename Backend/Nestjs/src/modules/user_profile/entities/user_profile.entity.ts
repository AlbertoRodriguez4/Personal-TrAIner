import { Entity, PrimaryGeneratedColumn, Column } from 'typeorm';

@Entity('Perfiles_Usuario')
export class UserProfile {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ unique: true })
  user_id: string;

  @Column({ type: 'int', nullable: true })
  dias_entrenamiento_semana: number;

  @Column({ type: 'varchar', length: 50, nullable: true })
  intensidad: string;

  @Column({ type: 'varchar', length: 50, nullable: true })
  nivel_experiencia: string;

  @Column({ type: 'simple-array', nullable: true })
  objetivos: string[];

  @Column({ type: 'varchar', length: 50, nullable: true })
  tipo_cuerpo: string;

  @Column({ type: 'text', nullable: true })
  condiciones_medicas: string;

  @Column({ type: 'decimal', precision: 5, scale: 2, nullable: true })
  bmi: number;

  @Column({ type: 'decimal', precision: 5, scale: 2, nullable: true })
  dexa_porcentaje_grasa: number;

  @Column({ type: 'decimal', precision: 6, scale: 2, nullable: true })
  dexa_masa_muscular_kg: number;

  @Column({ type: 'text', nullable: true })
  notas_adicionales: string;

  @Column({ type: 'timestamp', default: () => 'CURRENT_TIMESTAMP' })
  fecha_creacion: Date;

  @Column({ type: 'timestamp', default: () => 'CURRENT_TIMESTAMP', onUpdate: 'CURRENT_TIMESTAMP' })
  fecha_actualizacion: Date;
}
