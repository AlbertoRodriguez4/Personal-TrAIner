import { Entity, PrimaryGeneratedColumn, Column } from 'typeorm';

export interface EjercicioDia {
  nombre: string;
  series: number;
  repeticiones: number;
  descanso_segundos: number;
  notas?: string;
}

export interface DiaEntrenamiento {
  numero_dia: number;
  nombre_dia: string;
  grupo_muscular: string;
  ejercicios: EjercicioDia[];
}

@Entity('Rutinas_Personalizadas')
export class CustomRoutine {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_id' })
  userId: string;

  @Column({ type: 'varchar', length: 100 })
  nombre_rutina: string;

  @Column({ type: 'varchar', length: 50 })
  tipo_entrenamiento: string;

  @Column({ type: 'int' })
  numero_dias: number;

  @Column({ type: 'jsonb' })
  dias_entrenamiento: DiaEntrenamiento[];

  @Column({ type: 'text', nullable: true })
  notas_adicionales?: string;

  @Column({ type: 'boolean', default: false })
  activa: boolean;

  @Column({ type: 'timestamp', default: () => 'CURRENT_TIMESTAMP' })
  fecha_creacion: Date;

  @Column({ type: 'timestamp', default: () => 'CURRENT_TIMESTAMP', onUpdate: 'CURRENT_TIMESTAMP' })
  fecha_actualizacion: Date;
}
