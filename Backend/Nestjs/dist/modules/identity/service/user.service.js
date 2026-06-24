"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.UserService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const bcrypt = __importStar(require("bcrypt"));
const user_entity_1 = require("../entities/user.entity");
let UserService = class UserService {
    userRepository;
    constructor(userRepository) {
        this.userRepository = userRepository;
    }
    /**
     * MÉTODO DE REGISTRO
     * Reemplaza a tu antiguo 'create'. Verifica duplicados y encripta la contraseña.
     */
    async register(createUserDto) {
        // 1. Verificar si el correo ya existe
        const userExists = await this.userRepository.findOne({
            where: { email: createUserDto.email }
        });
        if (userExists) {
            throw new common_1.ConflictException('El correo electrónico ya está registrado.');
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
    async login(email, pass) {
        // 1. Buscar al usuario por email
        const user = await this.userRepository.findOne({
            where: { email }
        });
        if (!user) {
            throw new common_1.UnauthorizedException('Credenciales incorrectas (Usuario no encontrado).');
        }
        // 2. Comparar la contraseña ingresada con la encriptada en la base de datos
        const isPasswordValid = await bcrypt.compare(pass, user.password);
        if (!isPasswordValid) {
            throw new common_1.UnauthorizedException('Credenciales incorrectas (Contraseña inválida).');
        }
        // 5. Separamos la contraseña del resto de los datos usando desestructuración
        const { password: _, ...userWithoutPassword } = user;
        return userWithoutPassword;
    }
    // --- MÉTODOS CRUD ESTÁNDAR ---
    // Opcional: Puedes mantener este si necesitas crear usuarios internamente sin validaciones de Auth
    async create(createUserDto) {
        const newUser = this.userRepository.create(createUserDto);
        return await this.userRepository.save(newUser);
    }
    async findAll() {
        return await this.userRepository.find();
    }
    async findOne(id) {
        return await this.userRepository.findOneBy({ id });
    }
    async update(id, updateUserDto) {
        await this.userRepository.update(id, updateUserDto);
        return this.findOne(id);
    }
    async remove(id) {
        const user = await this.findOne(id);
        if (user) {
            await this.userRepository.remove(user);
            return { message: 'Usuario eliminado correctamente' };
        }
        return { message: 'Usuario no encontrado' };
    }
};
exports.UserService = UserService;
exports.UserService = UserService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(user_entity_1.User)),
    __metadata("design:paramtypes", [typeorm_2.Repository])
], UserService);
