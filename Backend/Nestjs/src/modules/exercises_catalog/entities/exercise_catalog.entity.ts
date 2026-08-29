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

  /// Imagen del ejercicio en el repo de origen (`free-exercise-db`). Nullable
  /// porque los ejercicios anteriores a esa importacion no tienen ninguna, y
  /// tambien es lo que distingue a los importados de los escritos a mano — el
  /// `down` de la migracion 1787100000000 se apoya en eso.
  @Column({ type: 'text', nullable: true })
  imagen_url: string | null;
}