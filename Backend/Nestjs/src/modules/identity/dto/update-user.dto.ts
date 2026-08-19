import {
  IsString,
  IsNotEmpty,
  IsNumber,
  Min,
  Max,
  IsDateString,
  IsOptional,
} from 'class-validator';

/// Edición parcial de un usuario ya creado.
///
/// Existe aparte de `UserDto` por dos motivos:
///
/// 1. `UserDto` marca todos los campos como `@IsNotEmpty()`, incluida la
///    contraseña. Con él, cambiar la altura desde el configurador de perfil
///    obligaba a reenviar la contraseña en claro, y sin ella el PUT devolvía un
///    400.
/// 2. **La contraseña no está aquí a propósito.** `update()` escribe el DTO tal
///    cual en la tabla, así que una contraseña que llegara por esta ruta se
///    guardaría sin hashear y dejaría la cuenta con una credencial en claro
///    junto a los hashes de bcrypt del registro. Cambiar la contraseña necesita
///    su propio flujo, no puede ser un efecto secundario de editar el perfil.
export class UpdateUserDto {
  @IsOptional()
  @IsString({ message: 'El nombre debe ser una cadena de texto válida' })
  @IsNotEmpty({ message: 'El nombre completo no puede quedar vacío' })
  nombre_completo?: string;

  @IsOptional()
  @IsDateString(
    {},
    { message: 'La fecha de nacimiento debe ser una fecha válida (YYYY-MM-DD)' },
  )
  fecha_nacimiento?: string;

  @IsOptional()
  @IsNumber({}, { message: 'La estatura debe ser un número' })
  @Min(50, { message: 'La estatura base debe ser de al menos 50 cm' })
  @Max(300, { message: 'La estatura base ingresada excede el límite permitido' })
  estatura_base_cm?: number;

  @IsOptional()
  @IsNumber({}, { message: 'El peso debe ser un número' })
  @Min(20, { message: 'El peso base debe ser de al menos 20 kg' })
  @Max(500, { message: 'El peso base ingresado excede el límite permitido' })
  peso_base_kg?: number;
}
