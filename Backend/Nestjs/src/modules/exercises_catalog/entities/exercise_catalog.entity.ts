import { Entity, PrimaryGeneratedColumn, Column } from 'typeorm';

@Entity('Ejercicios_Catalogo')
export class ExerciseCatalog {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'varchar', length: 100, unique: true })
  nombre: string;

  @Column({ type: 'varchar', length: 50 })
  grupo_muscular: string;

  @Column({ type: 'varchar', length: 50, nullable: true })
  equipamiento: string | null;

  @Column({ type: 'text', nullable: true })
  descripcion: string | null;
}