import {
    BadRequestException,
    ConflictException,
    Injectable,
    NotFoundException,
    UnauthorizedException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import * as bcrypt from 'bcrypt';
import { OAuth2Client, TokenPayload } from 'google-auth-library';
import { User } from '../entities/user.entity';
import { JwtService } from '@nestjs/jwt';
import { UserDto } from '../dto/user.dto';
import { UpdateUserDto } from '../dto/update-user.dto';
import { ChangePasswordDto } from '../dto/change-password.dto';

const googleClient = new OAuth2Client('853300599803-1tatkkepfmnkfavg8dqjk0b3dg648glt.apps.googleusercontent.com');

@Injectable()
export class UserService {
    constructor(
        @InjectRepository(User)
        private readonly userRepository: Repository<User>,
        private readonly jwtService: JwtService,
    ) { }

    /**
     * MÉTODO DE REGISTRO
     * Reemplaza a tu antiguo 'create'. Verifica duplicados y encripta la contraseña.
     */
    async register(createUserDto: UserDto) {
        // 1. Verificar si el correo ya existe
        const userExists = await this.userRepository.findOne({ 
            where: { email: createUserDto.email } 
        });

        if (userExists) {
            throw new ConflictException('El correo electrónico ya está registrado.');
        }

        // 2. Encriptar la contraseña (necesitas añadir 'password' a tu UserDto)
        // Usamos un "salt" de 10 rondas, que es el estándar de seguridad actual
        const hashedPassword = await bcrypt.hash(createUserDto.password, 10);

        // 3. Crear el usuario campo a campo. Nada de `...createUserDto`: el
        // ValidationPipe no descartaba propiedades desconocidas, y un `id` en el
        // cuerpo hacía que `save()` ACTUALIZASE la fila de ese usuario con el
        // correo y la contraseña del atacante — secuestro de cuenta sin token.
        const newUser = this.userRepository.create({
            nombre_completo: createUserDto.nombre_completo,
            email: createUserDto.email,
            password: hashedPassword,
            fecha_nacimiento: createUserDto.fecha_nacimiento,
            estatura_base_cm: createUserDto.estatura_base_cm,
            peso_base_kg: createUserDto.peso_base_kg,
            mapeo_identidad: createUserDto.mapeo_identidad,
        });

        // 4. Guardar en base de datos
       const savedUser = await this.userRepository.save(newUser);

        // 5. Separamos la contraseña del resto de los datos usando desestructuración
        const { password, ...userWithoutPassword } = savedUser;

        return this.conToken(userWithoutPassword);
    }

    /**
     * MÉTODO DE LOGIN
     * Busca al usuario y compara la contraseña desencriptada.
     */
    async login(email: string, pass: string) {
        // 1. Buscar al usuario por email. El hash hay que pedirlo aparte: la
        // columna es `select: false` para que no salga en ninguna otra consulta.
        const user = await this.userRepository
            .createQueryBuilder('user')
            .addSelect('user.password')
            .where('user.email = :email', { email })
            .getOne();

        if (!user) {
            throw new UnauthorizedException('Credenciales incorrectas (Usuario no encontrado).');
        }

        // Las cuentas creadas con Google no tienen contraseña: sin esto,
        // `bcrypt.compare` contra `null` lanzaba y el login respondía un 500.
        if (!user.password) {
            throw new UnauthorizedException(
                'Esta cuenta se creó con Google: inicia sesión con Google.',
            );
        }

        // 2. Comparar la contraseña ingresada con la encriptada en la base de datos
        const isPasswordValid = await bcrypt.compare(pass, user.password);

        if (!isPasswordValid) {
            throw new UnauthorizedException('Credenciales incorrectas (Contraseña inválida).');
        }

        // 5. Separamos la contraseña del resto de los datos usando desestructuración
        const { password: _, ...userWithoutPassword } = user;

        return this.conToken(userWithoutPassword);
    }

    async googleLogin(idToken: string) {
        if (typeof idToken !== 'string' || !idToken) {
            throw new BadRequestException('Falta el idToken de Google.');
        }

        // Un token caducado o manipulado hace que `verifyIdToken` lance: es un
        // 401, no el 500 que salía sin capturarlo.
        let payload: TokenPayload | undefined;
        try {
            const ticket = await googleClient.verifyIdToken({
                idToken,
                audience: '853300599803-1tatkkepfmnkfavg8dqjk0b3dg648glt.apps.googleusercontent.com',
            });
            payload = ticket.getPayload();
        } catch {
            throw new UnauthorizedException('Token de Google inválido');
        }
        if (!payload?.email) {
            throw new UnauthorizedException('Token de Google inválido');
        }

        // La cuenta se busca por correo, así que el correo tiene que estar
        // verificado por Google: si no, cualquiera con una cuenta de Google a
        // nombre de un correo ajeno entraría en la cuenta de su dueño.
        if (payload.email_verified !== true) {
            throw new UnauthorizedException('El correo de esta cuenta de Google no está verificado.');
        }

        const { email, name, sub } = payload;

        let user = await this.userRepository.findOne({ where: { email } });

        if (!user) {
            // Register new user
            user = this.userRepository.create({
                email,
                nombre_completo: name || 'Usuario de Google',
                mapeo_identidad: sub,
                fecha_nacimiento: new Date('2000-01-01'), // Valor por defecto
                estatura_base_cm: 170.0, // Valor por defecto
                peso_base_kg: 70.0, // Valor por defecto
                // password es nullable
            });
            await this.userRepository.save(user);
        }

        const { password, ...userWithoutPassword } = user;
        return this.conToken(userWithoutPassword);
    }

    /// Añade el token de sesión a la respuesta de registro/login.
    ///
    /// El `sub` del token es lo ÚNICO en lo que confía `JwtAuthGuard` para saber
    /// quién pide: el `userId` que venga en la URL o en el cuerpo se compara
    /// contra este, nunca al revés.
    private conToken<T extends { id: string }>(usuario: T) {
        return {
            ...usuario,
            access_token: this.jwtService.sign({ sub: usuario.id }),
        };
    }

    // --- MÉTODOS CRUD ESTÁNDAR ---
    //
    // `create()` y `findAll()` se han retirado junto con `POST /users` y
    // `GET /users` (ver UserController): el primero guardaba la contraseña sin
    // hashear, y dejarlos aquí solo invitaba a volver a enchufarlos.

    async findOne(id: string) {
        return await this.userRepository.findOneBy({ id });
    }

    /// Solo los campos editables, copiados uno a uno. `UpdateUserDto` no trae la
    /// contraseña, pero eso no bastaba: el ValidationPipe no descartaba lo que el
    /// DTO no declara, así que un `password` en el cuerpo llegaba igual a la
    /// tabla — en claro, junto a los hashes de bcrypt.
    async update(id: string, updateUserDto: UpdateUserDto) {
        const { nombre_completo, fecha_nacimiento, estatura_base_cm, peso_base_kg } =
            updateUserDto;
        // Fuera lo que no llega y también `null`: las cuatro columnas son NOT
        // NULL, y `@IsOptional()` deja pasar un null que acababa en un 500.
        const cambios = Object.fromEntries(
            Object.entries({
                nombre_completo,
                fecha_nacimiento,
                estatura_base_cm,
                peso_base_kg,
            }).filter(([, valor]) => valor !== undefined && valor !== null),
        );
        if (Object.keys(cambios).length) {
            await this.userRepository.update(id, cambios);
        }
        return this.findOne(id);
    }

    /// Los fallos son 400 y no 401 a propósito: la app trata cualquier 401 de
    /// una ruta con sesión como token caducado y manda al usuario al login, y
    /// equivocarse al teclear la contraseña actual no debería echarle.
    async changePassword(id: string, dto: ChangePasswordDto) {
        const user = await this.userRepository
            .createQueryBuilder('user')
            .addSelect('user.password')
            .where('user.id = :id', { id })
            .getOne();
        if (!user) {
            throw new NotFoundException('Usuario no encontrado.');
        }
        // Cuenta creada con Google: no tiene contraseña que comprobar, y dejar
        // poner una solo con el token daría una credencial nueva a quien lo
        // hubiera robado.
        if (!user.password) {
            throw new BadRequestException(
                'Esta cuenta entra con Google y no usa contraseña.',
            );
        }
        if (!(await bcrypt.compare(dto.actual, user.password))) {
            throw new BadRequestException('La contraseña actual no es correcta.');
        }
        if (dto.actual === dto.nueva) {
            throw new BadRequestException('La nueva contraseña es igual a la actual.');
        }
        await this.userRepository.update(id, {
            password: await bcrypt.hash(dto.nueva, 10),
        });
        return { message: 'Contraseña actualizada.' };
    }

    async remove(id: string) {
        const user = await this.findOne(id);
        if (user) {
            await this.userRepository.remove(user);
            return { message: 'Usuario eliminado correctamente' };
        }
        return { message: 'Usuario no encontrado' };
    }
}