import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, OneToMany, JoinColumn } from 'typeorm';
import { RoutineDay } from './routine_day.entity';

@Entity('routines')
export class Routine {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ nullable: true }) // Nullable para evitar crashear con rutinas antiguas sin migrar
  userId: string;

  @Column()
  name: string;

  @Column()
  activity_type: string;

  @Column({ nullable: true })
  description?: string;

  @OneToMany(() => RoutineDay, (day) => day.routine, { cascade: true })
  days: RoutineDay[];

  @Column({ default: true })
  activa: boolean;

  @Column({ type: 'timestamp', default: () => 'CURRENT_TIMESTAMP' })
  created_at: Date;

  @Column({ type: 'timestamp', default: () => 'CURRENT_TIMESTAMP', onUpdate: 'CURRENT_TIMESTAMP' })
  updated_at: Date;
}
