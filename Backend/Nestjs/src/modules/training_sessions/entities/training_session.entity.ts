import { Entity, PrimaryGeneratedColumn, Column } from 'typeorm';

@Entity('Sesiones_Entrenamiento')
export class TrainingSession {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column('uuid', { name: 'user_id' })
  userId: string;

  @Column({ type: 'timestamp' })
  fecha_programada: Date;

  @Column({ type: 'varchar', length: 50 })
  tipo_entrenamiento: string;

  @Column({ type: 'jsonb' })
  ejercicios: Record<string, unknown>[];

  @Column({ type: 'varchar', length: 30 })
  estado: string;

  @Column({ type: 'timestamp', nullable: true })
  fecha_finalizacion?: Date | null;
}
