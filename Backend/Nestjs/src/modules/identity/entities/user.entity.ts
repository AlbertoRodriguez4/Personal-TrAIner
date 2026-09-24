import { Entity, PrimaryGeneratedColumn, Column } from 'typeorm';

@Entity('Usuarios')
export class User {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  nombre_completo: string;

  @Column({ unique: true })
  email: string;

  /// `select: false`: el hash no sale en ninguna consulta salvo que se pida con
  /// `addSelect` (solo lo hace `login`). Antes `GET /users/:id` y el `PUT` lo
  /// devolvían dentro del usuario, y la app lo guardaba en su sesión local.
  @Column({ nullable: true, select: false })
  password: string;

  @Column({ type: 'date' })
  fecha_nacimiento: Date;

  @Column({ type: 'decimal', precision: 6, scale: 2 })
  estatura_base_cm: number;

  @Column({ type: 'decimal', precision: 6, scale: 2 })
  peso_base_kg: number;

  @Column({ nullable: true })
  mapeo_identidad: string;

  @Column({ type: 'timestamp', default: () => 'CURRENT_TIMESTAMP' })
  fecha_creacion: Date;
}
