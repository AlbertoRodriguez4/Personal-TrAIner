import {
    IsString,
    IsEmail,
    IsNotEmpty,
    IsNumber,
    Min,
    Max,
    IsDateString,
    MinLength,
    IsOptional
} from 'class-validator';

export class UserDto {

    @IsString({ message: 'El nombre debe ser una cadena de texto válida' })
    @IsNotEmpty({ message: 'El nombre completo es obligatorio' })
    nombre_completo: string;

    @IsEmail({}, { message: 'El formato del correo electrónico es inválido' })
    @IsNotEmpty({ message: 'El correo electrónico es obligatorio' })
    email: string;

    // --- NUEVO CAMPO: CONTRASEÑA ---
    @IsString({ message: 'La contraseña debe ser una cadena de texto' })
    @IsNotEmpty({ message: 'La contraseña es obligatoria' })
    @MinLength(6, { message: 'La contraseña debe tener al menos 6 caracteres' })
    password: string;

    @IsDateString({}, { message: 'La fecha de nacimiento debe ser una fecha válida (YYYY-MM-DD)' })
    @IsNotEmpty({ message: 'La fecha de nacimiento es obligatoria' })
    fecha_nacimiento: string;

    @IsNumber({}, { message: 'La estatura debe ser un número' })
    @Min(50, { message: 'La estatura base debe ser de al menos 50 cm' })
    @Max(300, { message: 'La estatura base ingresada excede el límite permitido' })
    @IsNotEmpty({ message: 'La estatura es obligatoria para los cálculos biométricos' })
    estatura_base_cm: number;

    @IsNumber({}, { message: 'El peso debe ser un número' })
    @Min(20, { message: 'El peso base debe ser de al menos 20 kg' })
    @Max(500, { message: 'El peso base ingresado excede el límite permitido' })
    @IsNotEmpty({ message: 'El peso es obligatorio para los cálculos biométricos' })
    peso_base_kg: number;

    // --- CAMBIO: AHORA ES OPCIONAL ---
    // Si el usuario se registra con email/password, esto puede venir vacío. 
    // Solo se llenará si decide iniciar sesión con Google/Apple.
    @IsOptional()
    
    @IsString({ message: 'El mapeo de identidad debe ser un texto válido' })
    mapeo_identidad?: string;
}