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

  /// Miniatura del ejercicio, copiada del catálogo al añadirlo a la rutina.
  ///
  /// Se guarda aquí en vez de resolverse por `name` contra `Ejercicios_Catalogo`
  /// en cada lectura porque el nombre del ejercicio de una rutina es editable y
  /// puede no existir en el catálogo (alta manual, ejercicio inventado): con un
  /// join por nombre, renombrar "Press banca" a "Press banca pesado" dejaría la
  /// ficha sin foto sin que se vea por qué.
  @Column({ type: 'text', nullable: true })
  imagen_url?: string;

  @ManyToOne(() => RoutineDay, (day) => day.exercises, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'routine_day_id' })
  day: RoutineDay;
}
