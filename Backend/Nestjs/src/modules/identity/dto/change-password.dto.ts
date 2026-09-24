import { IsNotEmpty, IsString, MinLength } from 'class-validator';

/// Cambio de contraseña con la sesión abierta. Pide la actual a propósito: sin
/// ella, un token robado bastaría para quedarse la cuenta para siempre, más
/// allá de los 30 días que dura el token.
export class ChangePasswordDto {
  @IsString()
  @IsNotEmpty({ message: 'Escribe tu contraseña actual.' })
  actual: string;

  @IsString()
  @MinLength(6, { message: 'La nueva contraseña debe tener al menos 6 caracteres' })
  nueva: string;
}
