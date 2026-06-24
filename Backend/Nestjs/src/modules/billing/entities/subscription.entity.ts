import { Entity, PrimaryGeneratedColumn, Column } from 'typeorm';

@Entity('Facturacion_Suscripciones')
export class Subscription {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column('uuid', { name: 'user_id' })
  userId: string;

  @Column({ type: 'varchar', length: 30 })
  plan: string;

  @Column({ type: 'varchar', length: 30 })
  estado: string;

  @Column({ type: 'date' })
  fecha_inicio: Date;

  @Column({ type: 'date' })
  fecha_fin: Date;
}
