import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, JoinColumn } from 'typeorm';
import { RoutineDay } from './routine_day.entity';

@Entity('exercises')
export class Exercise {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  name: string;

  @Column({ nullable: true })
  sets?: number;

  @Column({ nullable: true })
  reps?: string;

  @Column({ type: 'float', nullable: true })
  weight?: number;

  @Column({ nullable: true })
  duration?: string;

  @Column({ type: 'text', nullable: true })
  notes?: string;

  @Column({ nullable: true })
  rest_seconds?: number;

  /// Peso de cada serie, para los ejercicios en rampa (60-65-70).
  ///
  /// `weight` sigue siendo el peso de referencia del ejercicio y se mantiene
  /// para las rutinas que no suben: apuntar solo uno obliga a elegir entre
  /// quedarse corto en las ultimas series o ir sobrado en las primeras.
  @Column({ type: 'jsonb', nullable: true })
  weights?: number[];

  @ManyToOne(() => RoutineDay, (day) => day.exercises, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'routine_day_id' })
  day: RoutineDay;
}
