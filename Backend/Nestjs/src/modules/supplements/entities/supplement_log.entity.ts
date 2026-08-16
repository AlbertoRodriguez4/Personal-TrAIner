import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, JoinColumn } from 'typeorm';
import { Supplement } from './supplement.entity';

@Entity('Suplementos_Registro_Diario')
export class SupplementLog {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'varchar', name: 'user_id' })
  userId: string;

  @ManyToOne(() => Supplement, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'supplement_id' })
  supplement: Supplement;

  @Column({ type: 'uuid', name: 'supplement_id' })
  supplementId: string;

  @Column({ type: 'date' })
  fecha: Date;
}
