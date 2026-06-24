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

  @ManyToOne(() => RoutineDay, (day) => day.exercises, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'routine_day_id' })
  day: RoutineDay;
}
