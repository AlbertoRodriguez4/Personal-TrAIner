import { Entity, PrimaryGeneratedColumn, Column } from 'typeorm';

@Entity('Registros_Nutricionales_Cualitativos')
export class NutritionLog {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column('uuid', { name: 'user_id' })
  userId: string;

  @Column({ type: 'date' })
  fecha_registro: Date;

  @Column('int')
  calorias_consumidas: number;

  @Column({ type: 'decimal', precision: 6, scale: 2 })
  proteinas_g: number;

  @Column({ type: 'decimal', precision: 6, scale: 2 })
  carbohidratos_g: number;

  @Column({ type: 'decimal', precision: 6, scale: 2 })
  grasas_g: number;

  @Column({ type: 'text', nullable: true })
  notas?: string | null;

  @Column({ type: 'varchar', length: 20, default: 'otro' })
  tipo_comida: string;

  @Column({ type: 'varchar', length: 150, nullable: true })
  nombre_alimento?: string | null;
}
