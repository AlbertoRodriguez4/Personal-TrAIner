import { Injectable, ConflictException, UnauthorizedException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import * as bcrypt from 'bcrypt';
import { LoginTicket, OAuth2Client } from 'google-auth-library';
import { User } from '../entities/user.entity';
import { JwtService } from '@nestjs/jwt';
import { UserDto } from '../dto/user.dto';
import { UpdateUserDto } from '../dto/update-user.dto';

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

        // 3. Crear el usuario fusionando los datos del DTO con la contraseña encriptada
        const newUser = this.userRepository.create({
            ...createUserDto,
            password: hashedPassword,
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
        // 1. Buscar al usuario por email
        const user = await this.userRepository.findOne({ 
            where: { email } 
        });

        if (!user) {
            throw new UnauthorizedException('Credenciales incorrectas (Usuario no encontrado).');
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
        // `verifyIdToken` lanza en crudo cuando el token no vale (caducado, de
        // otro cliente, o directamente basura), y eso salia como un 500
        // "Internal server error" — indistinguible desde la app de un backend
        // roto, que es justo lo que parecia. Es un 401.
        let ticket: LoginTicket;
        try {
            ticket = await googleClient.verifyIdToken({
                idToken,
                audience: '853300599803-1tatkkepfmnkfavg8dqjk0b3dg648glt.apps.googleusercontent.com',
            });
        } catch (e) {
            throw new UnauthorizedException(
                `Token de Google no valido: ${e instanceof Error ? e.message : e}`,
            );
        }
        const payload = ticket.getPayload();
        if (!payload) {
            throw new UnauthorizedException('Token de Google inválido');
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

    // Opcional: Puedes mantener este si necesitas crear usuarios internamente sin validaciones de Auth
    async create(createUserDto: UserDto) {
        const newUser = this.userRepository.create(createUserDto);
        return await this.userRepository.save(newUser);
    }

    async findAll() {
        return await this.userRepository.find();
    }

    async findOne(id: string) {
        return await this.userRepository.findOneBy({ id });
    }

    /// El DTO se escribe tal cual en la tabla, así que solo puede traer campos
    /// que sean seguros de guardar sin transformar. `UpdateUserDto` no incluye
    /// la contraseña justamente por eso.
    async update(id: string, updateUserDto: UpdateUserDto) {
        await this.userRepository.update(id, updateUserDto);
        return this.findOne(id);
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