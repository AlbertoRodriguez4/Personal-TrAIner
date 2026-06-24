import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, OneToMany, JoinColumn } from 'typeorm';
import { Routine } from './routine.entity';
import { Exercise } from './exercise.entity';

@Entity('routine_days')
export class RoutineDay {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  day_of_week: string;

  @Column({ nullable: true })
  focus?: string;

  @ManyToOne(() => Routine, (routine) => routine.days, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'routine_id' })
  routine: Routine;

  @OneToMany(() => Exercise, (exercise) => exercise.day, { cascade: true })
  exercises: Exercise[];
}
