import { Entity, PrimaryGeneratedColumn, Column } from 'typeorm';

@Entity('Sesiones_Entrenamiento')
export class TrainingSession {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column('uuid', { name: 'user_id' })
  userId: string;

  @Column({ type: 'timestamp' })
  fecha_programada: Date;

  @Column({ type: 'varchar', length: 50 })
  tipo_entrenamiento: string;

  @Column({ type: 'jsonb' })
  ejercicios: Record<string, unknown>[];

  @Column({ type: 'varchar', length: 30 })
  estado: string;

  @Column({ type: 'timestamp', nullable: true })
  fecha_finalizacion?: Date | null;

  // ===== Métricas clave, para analizar la sesión y compararla con la media =====
  // Todas nullable: de dónde salga la sesión decide cuáles se pueden rellenar.
  // Un registro narrado por chat puede no traer ninguna; uno de Health Connect
  // trae casi todas; uno en vivo desde la app trae las que mide la banda BLE.

  @Column({ type: 'int', nullable: true })
  duracion_minutos?: number | null;

  @Column({ type: 'int', nullable: true })
  calorias_kcal?: number | null;

  @Column({ type: 'int', nullable: true })
  frecuencia_cardiaca_media?: number | null;

  @Column({ type: 'int', nullable: true })
  frecuencia_cardiaca_max?: number | null;

  @Column({ type: 'decimal', precision: 6, scale: 2, nullable: true })
  distancia_km?: number | null;

  /// 'manual' (narrado por chat) | 'app' (rastreada en vivo con banda BLE) |
  /// 'health_connect' (sincronizada de un entrenamiento ya grabado en el móvil).
  /// Decide cuánto fiarse de las métricas: 'app' y 'health_connect' son
  /// medidas, 'manual' es lo que el usuario recuerda o estima.
  @Column({ type: 'varchar', length: 20, default: 'manual' })
  origen: string;

  /// Identidad estable del entrenamiento de origen cuando `origen` no es
  /// 'manual' (para 'health_connect', el `dateFrom` ISO del `HealthDataPoint`).
  /// Sin esto, sincronizar dos veces duplicaría la sesión: no hay otra forma
  /// de saber que un WORKOUT que ya se leyó de Health Connect es el mismo que
  /// se guardó la vez anterior, porque Health Connect no expone un id estable
  /// a través del plugin que usa la app.
  @Column({ type: 'varchar', length: 60, nullable: true })
  origen_id?: string | null;
}
