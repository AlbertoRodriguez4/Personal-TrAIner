import { Entity, PrimaryGeneratedColumn, Column } from 'typeorm';

@Entity('Densitometrias_DEXA')
export class DexaScan {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column('uuid', { name: 'user_id' })
  userId: string;

  @Column({ type: 'date' })
  fecha_escaneo: Date;

  @Column({ type: 'decimal', precision: 5, scale: 2 })
  porcentaje_grasa: number;

  @Column({ type: 'decimal', precision: 8, scale: 2 })
  masa_muscular_kg: number;

  @Column({ type: 'decimal', precision: 6, scale: 3 })
  densidad_osea: number;
}
