import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  ManyToOne,
  JoinColumn,
  Index,
} from 'typeorm';
import { ClinicalReport } from './clinical_report.entity';

/// Un valor de biomarcador con su fecha. Es la tabla que hace posible la
/// tendencia ("tu ferritina bajó de 80 a 35 en 6 meses"): una fila por
/// medición, nunca un UPDATE sobre la anterior.
///
/// `report_id` es nullable a propósito: los valores que el usuario mete a mano
/// en la pantalla de Clínica no vienen de ningún documento.
@Entity('Biomarcadores_Clinicos')
export class ClinicalMarker {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Index()
  @Column({ name: 'user_id' })
  userId: string;

  @Column({ name: 'report_id', type: 'uuid', nullable: true })
  reportId: string | null;

  @ManyToOne(() => ClinicalReport, (report) => report.marcadores, {
    onDelete: 'CASCADE',
    nullable: true,
  })
  @JoinColumn({ name: 'report_id' })
  report: ClinicalReport | null;

  @Index()
  @Column({ type: 'date' })
  fecha: Date;

  /// Slug canónico (`colesterol_total`, `hba1c`, `ferritina`…). Es la clave por
  /// la que se agrupan las series temporales, así que tiene que venir
  /// normalizado desde Python — nunca el texto literal del laboratorio.
  @Column({ type: 'varchar', length: 60 })
  codigo: string;

  @Column({ type: 'varchar', length: 120 })
  nombre: string;

  @Column({ type: 'numeric', precision: 12, scale: 4 })
  valor: number;

  @Column({ type: 'varchar', length: 30, nullable: true })
  unidad: string | null;

  /// Rango que aplicó la interpretación. Prioridad: el impreso en el informe
  /// del propio laboratorio; si no lo hay, el de la tabla de referencia.
  @Column({ type: 'numeric', precision: 12, scale: 4, nullable: true })
  rango_min: number | null;

  @Column({ type: 'numeric', precision: 12, scale: 4, nullable: true })
  rango_max: number | null;

  /// 'bajo' | 'normal' | 'alto' | 'desconocido'
  @Column({ type: 'varchar', length: 20, default: 'desconocido' })
  estado: string;

  /// Por qué este valor importa para construir físico (síntesis proteica,
  /// recuperación, rendimiento…). Lo redacta la IA apoyada en las fuentes.
  @Column({ type: 'text', nullable: true })
  relevancia_fisico: string | null;

  /// 'documento_ia' | 'manual'
  @Column({ type: 'varchar', length: 20, default: 'documento_ia' })
  origen: string;
}
