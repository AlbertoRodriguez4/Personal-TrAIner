import { Injectable, ConflictException, UnauthorizedException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import * as bcrypt from 'bcrypt';
import { OAuth2Client } from 'google-auth-library';
import { User } from '../entities/user.entity';
import { UserDto } from '../dto/user.dto';

const googleClient = new OAuth2Client('853300599803-1tatkkepfmnkfavg8dqjk0b3dg648glt.apps.googleusercontent.com');

@Injectable()
export class UserService {
    constructor(
        @InjectRepository(User)
        private readonly userRepository: Repository<User>,
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
        
        return userWithoutPassword;
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
        
        return userWithoutPassword;
    }

    async googleLogin(idToken: string) {
        const ticket = await googleClient.verifyIdToken({
            idToken,
            audience: '853300599803-1tatkkepfmnkfavg8dqjk0b3dg648glt.apps.googleusercontent.com',
        });
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
        return userWithoutPassword;
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

    async update(id: string, updateUserDto: UserDto) {
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