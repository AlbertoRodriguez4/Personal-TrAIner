import { Entity, PrimaryGeneratedColumn, Column } from 'typeorm';

@Entity('Evaluaciones_Posturales_Visuales')
export class PostureEvaluation {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column('uuid', { name: 'user_id' })
  userId: string;

  @Column({ type: 'timestamp' })
  fecha_evaluacion: Date;

  @Column({ type: 'text' })
  imagen_frontal_url: string;

  @Column({ type: 'text' })
  imagen_lateral_url: string;

  @Column({ type: 'decimal', precision: 5, scale: 2 })
  puntuacion_postura: number;

  @Column({ type: 'text' })
  analisis_ia: string;
}
