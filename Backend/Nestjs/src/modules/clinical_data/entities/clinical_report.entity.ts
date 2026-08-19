import { Entity, PrimaryGeneratedColumn, Column, OneToMany } from 'typeorm';
import { ClinicalMarker } from './clinical_marker.entity';

/// Un documento clínico subido por el usuario (PDF, DICOM o foto de una
/// analítica) ya digerido por la IA: el archivo en sí NO se guarda, solo el
/// resumen y los biomarcadores extraídos. Lo que persiste es lo que la IA
/// necesita releer más adelante para construir rutinas y macros.
@Entity('Informes_Clinicos')
export class ClinicalReport {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_id' })
  userId: string;

  /// Cuándo lo subió el usuario. Es la fecha que se muestra en el historial.
  @Column({ type: 'timestamp', default: () => 'CURRENT_TIMESTAMP' })
  fecha_subida: Date;

  /// Fecha impresa en el propio documento (la extracción puede no encontrarla).
  @Column({ type: 'date', nullable: true })
  fecha_informe: Date | null;

  @Column({ type: 'varchar', length: 40, default: 'analitica' })
  tipo_documento: string;

  @Column({ type: 'varchar', length: 255, nullable: true })
  nombre_archivo: string | null;

  @Column({ type: 'text' })
  resumen_ia: string;

  /// jsonb y no `simple-array`: este último serializa a un CSV y cualquier
  /// frase con una coma dentro vuelve partida en varios elementos.
  @Column({ type: 'jsonb', nullable: true })
  hallazgos_clave: string[] | null;

  @Column({ type: 'text', nullable: true })
  implicaciones_entrenamiento: string | null;

  @Column({ type: 'text', nullable: true })
  implicaciones_nutricion: string | null;

  /// Valores fuera de rango que merecen que el usuario consulte con un médico.
  /// Nunca es un diagnóstico — es una señal de "esto no lo interpretes solo".
  @Column({ type: 'jsonb', nullable: true })
  banderas_rojas: string[] | null;

  /// Trazabilidad de las fuentes contrastadas consultadas antes de redactar
  /// (MedlinePlus/NIH, tabla de rangos de referencia con su cita). Sin esto no
  /// hay forma de auditar de dónde salió una afirmación del resumen.
  @Column({ type: 'jsonb', nullable: true })
  fuentes_consultadas: Record<string, unknown>[] | null;

  /// 'alta' | 'media' | 'baja' — qué tan legible era el documento.
  @Column({ type: 'varchar', length: 20, nullable: true })
  confianza_extraccion: string | null;

  @OneToMany(() => ClinicalMarker, (marker) => marker.report)
  marcadores: ClinicalMarker[];
}
