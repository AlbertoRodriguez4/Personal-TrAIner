import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  ManyToOne,
  JoinColumn,
  Index,
} from 'typeorm';
import { BodyAnalysisRecord } from './body_analysis_record.entity';

/// Las fotos de físico que acompañan a un `BodyAnalysisRecord`. Se guardan como
/// bytea (ya reescaladas en el cliente a ~1280px/JPEG 80) para que el historial
/// sea visual sin depender de almacenamiento externo ni de una ruta de ficheros
/// que haya que servir aparte.
@Entity('Fotos_Fisico')
export class PhysiquePhoto {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Index()
  @Column({ name: 'user_id' })
  userId: string;

  @Column({ name: 'record_id', type: 'uuid' })
  recordId: string;

  @ManyToOne(() => BodyAnalysisRecord, (record) => record.fotos, {
    onDelete: 'CASCADE',
  })
  @JoinColumn({ name: 'record_id' })
  record: BodyAnalysisRecord;

  /// 'frontal' | 'lateral' | 'espalda' | 'otro'
  @Column({ type: 'varchar', length: 20, default: 'otro' })
  angulo: string;

  @Column({ type: 'varchar', length: 40, default: 'image/jpeg' })
  mime_type: string;

  @Column({ type: 'bytea' })
  imagen: Buffer;

  @Column({ type: 'timestamp', default: () => 'CURRENT_TIMESTAMP' })
  created_at: Date;
}
