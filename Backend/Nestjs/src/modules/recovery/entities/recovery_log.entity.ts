import { Entity, PrimaryGeneratedColumn, Column } from 'typeorm';

@Entity('Registros_Recuperacion')
export class RecoveryLog {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'varchar', name: 'user_id' })
  userId: string;

  @Column({ type: 'date' })
  fecha: Date;

  @Column({ type: 'float', nullable: true })
  horas_sueno?: number;

  @Column({ type: 'varchar', length: 20, nullable: true })
  hrv_estado?: string;

  @Column({ type: 'int', nullable: true })
  frecuencia_cardiaca_reposo?: number;

  @Column({ type: 'int' })
  readiness_score: number;

  @Column({ type: 'varchar', length: 50, default: 'mi_fitness_health_connect' })
  fuente: string;

  @Column({ type: 'text', nullable: true })
  notas_ia?: string;

  @Column({ type: 'timestamp', default: () => 'CURRENT_TIMESTAMP' })
  created_at: Date;
}
