import { IsNotEmpty, IsString } from 'class-validator';

/// Sin DTO, un login sin `email` llegaba a `findOne({ where: { email: undefined } })`,
/// que TypeORM lee como "sin filtro" y devuelve el primer usuario de la tabla:
/// bastaba acertar SU contraseña para entrar sin saber su correo.
export class LoginDto {
  @IsString()
  @IsNotEmpty({ message: 'El correo electrónico es obligatorio' })
  email: string;

  @IsString()
  @IsNotEmpty({ message: 'La contraseña es obligatoria' })
  password: string;
}
